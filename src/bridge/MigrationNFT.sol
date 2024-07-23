// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity 0.8.23;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {NODLMigration} from "./NODLMigration.sol";
import {BridgeBase} from "./BridgeBase.sol";

contract MigrationNFT is ERC721 {
    uint256 public nextTokenId;
    uint256 public immutable maxHolders;
    NODLMigration public immutable migration;

    uint256[] public levels;
    string[] public levelToTokenURI;

    /**
     * @notice Mapping of token IDs to the levels they represent denominated from 1 (0 means token does not exists)
     */
    mapping(uint256 => uint256) public tokenIdToNextLevel;
    /**
     * @notice Mapping of holders to the highest level they reached (denominated from 1)
     */
    mapping(address => uint256) public holderToNextLevel;

    uint256 public individualHolders;
    mapping(bytes32 => bool) public claimed;

    error UnsortedLevelsList();
    error UnequalLengths();
    error TooManyHolders();
    error AlreadyClaimed();
    error NoLevelUp();
    error ProposalDoesNotExist();
    error NotExecuted();
    error SoulboundIsNotTransferrable();

    /**
     * @notice Construct a new MigrationNFT contract
     * @param _migration the NODLMigration contract to bridge tokens
     * @param _maxHolders the maximum number of holders for the NFTs
     * @param _levels an array representing the different reward levels expressed in
     *                the amount of tokens needed to get the NFT
     * @param _levelToTokenURI an array of URIs to the metadata of the NFTs
     */
    constructor(
        NODLMigration _migration,
        uint256 _maxHolders,
        uint256[] memory _levels,
        string[] memory _levelToTokenURI
    ) ERC721("OG ZK NODL", "OG_ZK_NODL") {
        migration = _migration;
        maxHolders = _maxHolders;
        levels = _levels;
        levelToTokenURI = _levelToTokenURI;

        if (_levels.length != _levelToTokenURI.length) {
            revert UnequalLengths();
        }

        for (uint256 i = 1; i < levels.length; i++) {
            if (levels[i] <= levels[i - 1]) {
                revert UnsortedLevelsList();
            }
        }
    }

    /**
     * @notice Return the URI of the proper metadata for the given token ID
     * @param tokenId the token ID to mint
     */
    function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
        _requireOwned(tokenId); // this will also mean that tokenIdToNextLevel is at least 1

        uint256 level = tokenIdToNextLevel[tokenId];
        return levelToTokenURI[level - 1];
    }

    /**
     * @notice Mint a new NFT for the given user
     * @param txHash the transaction hash to bridge
     */
    function safeMint(bytes32 txHash) public {
        _mustNotHaveBeenClaimed(txHash);

        (address target, uint256 amount, BridgeBase.ProposalStatus memory status) = migration.proposals(txHash);

        _mustBeAnExistingProposal(target);
        _mustBeExecuted(status.executed);
        bool alreadyHolder = _mustAlreadyBeHolderOrEnougHoldersRemaining(target);

        (uint256[] memory levelsToMint, uint256 nbLevelsToMint) = _computeLevelUps(target, amount);

        claimed[txHash] = true;
        if (!alreadyHolder) {
            individualHolders++;
        }

        for (uint256 i = 0; i < nbLevelsToMint; i++) {
            uint256 tokenId = nextTokenId++;
            tokenIdToNextLevel[tokenId] = levelsToMint[i] + 1;
            holderToNextLevel[target] = levelsToMint[i] + 1;
            _safeMint(target, tokenId);
        }
    }

    function _computeLevelUps(address target, uint256 amount)
        internal
        view
        returns (uint256[] memory levelsToMint, uint256 nbLevelsToMint)
    {
        levelsToMint = new uint256[](levels.length);
        nbLevelsToMint = 0;

        // We effectively iterate over all the levels the `target` has YET
        // to qualify for. This expressively skips levels the `target` has
        // already qualified for.
        uint256 nextLevel = holderToNextLevel[target];
        for (uint256 i = nextLevel; i < levels.length; i++) {
            if (amount >= levels[i]) {
                levelsToMint[i - nextLevel] = i;
                nbLevelsToMint++;
            }
        }

        if (nbLevelsToMint == 0) {
            revert NoLevelUp();
        }
    }

    function _mustNotHaveBeenClaimed(bytes32 txHash) internal view {
        if (claimed[txHash]) {
            revert AlreadyClaimed();
        }
    }

    function _mustBeAnExistingProposal(address target) internal pure {
        // the relayers skip any transfers to the 0 address
        if (target == address(0)) {
            revert ProposalDoesNotExist();
        }
    }

    function _mustBeExecuted(bool executed) internal pure {
        if (!executed) {
            revert NotExecuted();
        }
    }

    function _mustAlreadyBeHolderOrEnougHoldersRemaining(address target) internal view returns (bool alreadyHolder) {
        alreadyHolder = balanceOf(target) > 0;
        if (!alreadyHolder && individualHolders == maxHolders) {
            revert TooManyHolders();
        }
    }

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721) returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            // only burn or mint is allowed for a soulbound token
            revert SoulboundIsNotTransferrable();
        }

        return super._update(to, tokenId, auth);
    }
}
