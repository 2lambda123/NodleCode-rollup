import { expect } from 'chai';
import { Contract, Wallet } from "zksync-ethers";
import { getWallet, deployContract, LOCAL_RICH_WALLETS } from '../deploy/utils';
import * as ethers from "ethers";

describe("NODL", function () {
  let tokenContract: Contract;
  let ownerWallet: Wallet;
  let userWallet: Wallet;

  before(async function () {
    ownerWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
    userWallet = getWallet(LOCAL_RICH_WALLETS[1].privateKey);

    tokenContract = await deployContract("NODL", [ownerWallet.address, ownerWallet.address], { wallet: ownerWallet, silent: true, skipChecks: true });
  });

  it("Should be deployed with no supply", async function () {
    const initialSupply = await tokenContract.totalSupply();
    expect(initialSupply.toString()).to.equal("0");
  });

  it("Should be mintable", async () => {
    const balanceBefore = await tokenContract.balanceOf(userWallet.address);
    const mintAmount = ethers.parseEther("1000");
    const initialSupply = await tokenContract.totalSupply();

    await tokenContract.mint(userWallet.address, mintAmount);

    const balanceAfter = await tokenContract.balanceOf(userWallet.address);
    expect(balanceAfter).to.equal(balanceBefore + mintAmount);

    const finalSupply = await tokenContract.totalSupply();
    expect(finalSupply).to.equal(initialSupply + mintAmount);
  });

  it("Should be burnable", async () => {
    const balanceBefore = await tokenContract.balanceOf(userWallet.address);
    const burnAmount = ethers.parseEther("1000");
    const initialSupply = await tokenContract.totalSupply();

    await tokenContract.connect(userWallet).burn(burnAmount);

    const balanceAfter = await tokenContract.balanceOf(userWallet.address);
    expect(balanceAfter).to.equal(balanceBefore - burnAmount);

    const finalSupply = await tokenContract.totalSupply();
    expect(finalSupply).to.equal(initialSupply - burnAmount);
  });

  it("Has a max supply of 21 billion", async () => {
    const maxSupply = ethers.parseEther("21000000000");
    const cap = await tokenContract.cap();
    expect(cap).to.equal(maxSupply);
  });

  it("Cannot mint above max supply", async () => {
    const cap = await tokenContract.cap();
    const currentSupply = await tokenContract.totalSupply();

    const maxMint = cap - currentSupply;
    await tokenContract.mint(userWallet.address, maxMint);

    await expect(
      tokenContract.mint(userWallet.address, 1)
    ).to.be
      .revertedWithCustomError(tokenContract, "ERC20ExceededCap")
      .withArgs(cap + 1n, cap);
  });
});