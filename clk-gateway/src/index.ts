import express, { Request, Response } from "express";
import { Provider as L2Provider } from "zksync-ethers";
import {
  JsonRpcProvider as L1Provider,
  Contract,
  keccak256,
  toBigInt,
  toUtf8Bytes,
} from "ethers";
import {
  BatchMetadata,
  CommitBatchInfo,
  RpcProof,
  StorageProof,
  StorageProofBatch,
  StoredBatchInfo as BatchInfo,
} from "./types";
import {
  ZKSYNC_DIAMOND_INTERFACE,
  STORAGE_VERIFIER_INTERFACE,
  CLICK_NAME_SERVICE_INTERFACE,
} from "./interfaces";

import dotenv from "dotenv";
dotenv.config();

const app = express();
const port = process.env.PORT || 8080;
const l2Provider = new L2Provider(
  "https://shy-cosmopolitan-telescope.zksync-sepolia.quiknode.pro/7dca91c43e87ec74294608886badb962826e62a0"
);
const l1Provider = new L1Provider(
  "https://little-divine-needle.ethereum-sepolia.quiknode.pro/538abebc9495df79d5f5684483f9f479d9d6ec4f"
);
const diamondAddress = "0x9A6DE0f62Aa270A8bCB1e2610078650D539B1Ef9";
const diamondContract = new Contract(
  diamondAddress,
  ZKSYNC_DIAMOND_INTERFACE,
  l1Provider
);
const clickNameServiceAddress = "0x2c1B65dA72d5Cf19b41dE6eDcCFB7DD83d1B529E";
const clickNameServiceContract = new Contract(
  clickNameServiceAddress,
  CLICK_NAME_SERVICE_INTERFACE,
  l2Provider
);
const SAFE_BATCH_QUERY_OFFSET = 150;

/** Parses the transaction where batch is committed and returns commit info */
async function parseCommitTransaction(
  txHash: string,
  batchNumber: number
): Promise<{ commitBatchInfo: CommitBatchInfo; commitment: string }> {
  const transactionData = await l1Provider.getTransaction(txHash);
  const [, , newBatch] = ZKSYNC_DIAMOND_INTERFACE.decodeFunctionData(
    "commitBatchesSharedBridge",
    transactionData!.data
  );

  // Find the batch with matching number
  const batch = newBatch.find((batch: any) => {
    return batch[0] === BigInt(batchNumber);
  });
  if (batch == undefined) {
    throw new Error(`Batch ${batchNumber} not found in calldata`);
  }

  const commitBatchInfo: CommitBatchInfo = {
    batchNumber: batch[0],
    timestamp: batch[1],
    indexRepeatedStorageChanges: batch[2],
    newStateRoot: batch[3],
    numberOfLayer1Txs: batch[4],
    priorityOperationsHash: batch[5],
    bootloaderHeapInitialContentsHash: batch[6],
    eventsQueueStateHash: batch[7],
    systemLogs: batch[8],
    totalL2ToL1Pubdata: batch[9],
  };

  const receipt = await l1Provider.getTransactionReceipt(txHash);
  if (receipt == undefined) {
    throw new Error(`Receipt for commit tx ${txHash} not found`);
  }

  // Parse event logs of the transaction to find commitment
  const blockCommitFilter = ZKSYNC_DIAMOND_INTERFACE.encodeFilterTopics(
    "BlockCommit",
    [batchNumber]
  );
  const commitLog = receipt.logs.find(
    (log) =>
      log.address === diamondAddress &&
      blockCommitFilter.every((topic, i) => topic === log.topics[i])
  );
  if (commitLog == undefined) {
    throw new Error(`Commit log for batch ${batchNumber} not found`);
  }
  const { commitment } = ZKSYNC_DIAMOND_INTERFACE.decodeEventLog(
    "BlockCommit",
    commitLog.data,
    commitLog.topics
  );

  return { commitBatchInfo, commitment };
}
/** Returns logs root hash stored in L1 contract */
async function getL2LogsRootHash(batchNumber: number): Promise<string> {
  const l2RootsHash = await diamondContract.l2LogsRootHash(batchNumber);
  return String(l2RootsHash);
}

/**
 * Returns the batch info for the given batch number for those stored on L1.
 * Returns null if the batch is not stored.
 * @param batchNumber
 */
async function getBatchInfo(batchNumber: number): Promise<BatchInfo> {
  const { commitTxHash, proveTxHash } =
    await l2Provider.getL1BatchDetails(batchNumber);

  // If batch is not committed or proved, return null
  if (commitTxHash == undefined) {
    throw new Error(`Batch ${batchNumber} is not committed`);
  } else if (proveTxHash == undefined) {
    throw new Error(`Batch ${batchNumber} is not proved`);
  }

  // Parse commit calldata from commit transaction
  const { commitBatchInfo, commitment } = await parseCommitTransaction(
    commitTxHash,
    batchNumber
  );
  const l2LogsTreeRoot = await getL2LogsRootHash(batchNumber);

  const storedBatchInfo: BatchInfo = {
    batchNumber: commitBatchInfo.batchNumber,
    batchHash: commitBatchInfo.newStateRoot,
    indexRepeatedStorageChanges: commitBatchInfo.indexRepeatedStorageChanges,
    numberOfLayer1Txs: commitBatchInfo.numberOfLayer1Txs,
    priorityOperationsHash: commitBatchInfo.priorityOperationsHash,
    l2LogsTreeRoot,
    timestamp: commitBatchInfo.timestamp,
    commitment,
  };
  return storedBatchInfo;
}

// committedL1Batch endpoint which returns the L1 batch info for a pretty recently committed batch.
// SAFE_BATCH_QUERY_OFFSET is used to ensure that the batch is already committed and proved.
app.get("/committedL1Batch", async (req: Request, res: Response) => {
  try {
    const l1BatchNumber = await l2Provider.getL1BatchNumber();

    const batchNumber = l1BatchNumber - SAFE_BATCH_QUERY_OFFSET;

    const batchDetails = await l2Provider.getL1BatchDetails(batchNumber);

    if (batchDetails.commitTxHash == undefined) {
      throw new Error(`Batch ${batchNumber} is not committed`);
    }

    const batchInfo = await getBatchInfo(batchNumber);

    res.status(200).send({
      batchNumber: batchInfo.batchNumber.toString(),
      batchHash: batchInfo.batchHash,
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    res.status(500).send({ error: errorMessage });
  }
});

app.get("/expiry", async (req: Request, res: Response) => {
  try {
    const { name } = req.query;

    // TODO: add thorough sanity check for name
    if (!name || typeof name !== "string") {
      throw new Error("Name is required and must be a string");
    }

    const nameHash = keccak256(toUtf8Bytes(name));
    const key = toBigInt(nameHash);

    const value = await clickNameServiceContract.expires(nameHash);

    res.status(200).send({
      expires: value.toString(),
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    res.status(500).send({ error: errorMessage });
  }
});

// Start server
app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
