// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/NODL.sol";
import "../src/Rewards.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "./__helpers__/AccessControlUtils.sol";

contract RewardsTest is Test {
    using AccessControlUtils for Vm;

    NODL nodlToken;
    Rewards rewards;
    address recipient;
    uint256 oraclePrivateKey;

    uint256 constant RENEWAL_PERIOD = 1 days;

    function setUp() public {
        recipient = address(1);
        oraclePrivateKey = 0xBEEF;
        address oracle = vm.addr(oraclePrivateKey);

        nodlToken = new NODL();
        rewards = new Rewards(nodlToken, 1000, RENEWAL_PERIOD, oracle);
        // Grant MINTER_ROLE to the Rewards contract
        nodlToken.grantRole(nodlToken.MINTER_ROLE(), address(rewards));
    }

    function testSetQuota() public {
        // Check initial quota
        assertEq(rewards.quota(), 1000);

        address alice = address(2);

        // Assign QUOTA_SETTER_ROLE to the test contract
        rewards.grantRole(rewards.DEFAULT_ADMIN_ROLE(), alice);

        // Set the new quota
        vm.prank(alice);
        rewards.setQuota(2000);

        // Check new quota
        assertEq(rewards.quota(), 2000);
    }

    function testSetQuotaUnauthorized() public {
        address bob = address(3);
        vm.expectRevert_AccessControlUnauthorizedAccount(bob, rewards.DEFAULT_ADMIN_ROLE());
        vm.prank(bob);
        rewards.setQuota(2000);
    }

    function testMintReward() public {
        // Prepare the reward and signature
        Rewards.Reward memory reward = Rewards.Reward(recipient, 100, 0);
        bytes memory signature = createSignature(reward, oraclePrivateKey);

        // Mint reward
        rewards.mintReward(reward, signature);

        // Check balances and sequences
        assertEq(nodlToken.balanceOf(recipient), 100);
        assertEq(rewards.claimed(), 100);
        assertEq(rewards.sequences(recipient), 1);
    }

    function testMintRewardQuotaExceeded() public {
        // Prepare the reward and signature
        Rewards.Reward memory reward = Rewards.Reward(recipient, 1100, 0);
        bytes memory signature = createSignature(reward, oraclePrivateKey);

        // Expect the quota to be exceeded
        vm.expectRevert(Rewards.QuotaExceeded.selector);
        rewards.mintReward(reward, signature);
    }

    function testMintRewardUnauthorizedOracle() public {
        // Prepare the reward and signature with an unauthorized oracle
        Rewards.Reward memory reward = Rewards.Reward(recipient, 100, 0);
        bytes memory signature = createSignature(reward, 0xDEAD);

        // Expect unauthorized oracle error
        vm.expectRevert(Rewards.UnauthorizedOracle.selector);
        rewards.mintReward(reward, signature);
    }

    function testMintRewardInvalidsequence() public {
        // Prepare the reward and signature
        Rewards.Reward memory reward = Rewards.Reward(recipient, 100, 1); // Invalid sequence
        bytes memory signature = createSignature(reward, oraclePrivateKey);

        // Expect invalid recipient sequence error
        vm.expectRevert(Rewards.InvalidRecipientSequence.selector);
        rewards.mintReward(reward, signature);
    }

    function testMintBatchReward() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipients[0] = address(11);
        recipients[1] = address(22);
        amounts[0] = 100;
        amounts[1] = 200;

        Rewards.BatchReward memory rewardsBatch = Rewards.BatchReward(recipients, amounts, 0);

        bytes memory signature = createBatchSignature(rewardsBatch, oraclePrivateKey);

        rewards.mintBatchReward(rewardsBatch, signature);

        assertEq(nodlToken.balanceOf(recipients[0]), 100);
        assertEq(nodlToken.balanceOf(recipients[1]), 200);
        assertEq(rewards.claimed(), 300);
        assertEq(rewards.sequences(recipients[0]), 0);
        assertEq(rewards.sequences(recipients[1]), 0);
        assertEq(rewards.batchSequence(), 1);
    }

    function testMintBatchRewardQuotaExceeded() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipients[0] = address(11);
        recipients[1] = address(22);
        amounts[0] = 500;
        amounts[1] = 600;

        Rewards.BatchReward memory rewardsBatch = Rewards.BatchReward(recipients, amounts, 0);

        bytes memory signature = createBatchSignature(rewardsBatch, oraclePrivateKey);

        vm.expectRevert(Rewards.QuotaExceeded.selector);
        rewards.mintBatchReward(rewardsBatch, signature);
    }

    function testMintBatchRewardUnauthorizedOracle() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipients[0] = address(11);
        recipients[1] = address(22);
        amounts[0] = 100;
        amounts[1] = 200;

        Rewards.BatchReward memory rewardsBatch = Rewards.BatchReward(recipients, amounts, 0);

        bytes memory signature = createBatchSignature(rewardsBatch, 0xDEAD);

        vm.expectRevert(Rewards.UnauthorizedOracle.selector);
        rewards.mintBatchReward(rewardsBatch, signature);
    }

    function testMintBatchRewardInvalidSequence() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipients[0] = address(11);
        recipients[1] = address(22);
        amounts[0] = 100;
        amounts[1] = 200;

        Rewards.BatchReward memory rewardsBatch = Rewards.BatchReward(recipients, amounts, 1);

        bytes memory signature = createBatchSignature(rewardsBatch, oraclePrivateKey);

        vm.expectRevert(Rewards.InvalidBatchSequence.selector);
        rewards.mintBatchReward(rewardsBatch, signature);
    }

    function testMintBatchRewardInvalidStruct() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](1);

        recipients[0] = address(11);
        recipients[1] = address(22);
        amounts[0] = 100;

        Rewards.BatchReward memory rewardsBatch = Rewards.BatchReward(recipients, amounts, 0);

        bytes memory signature = createBatchSignature(rewardsBatch, oraclePrivateKey);

        vm.expectRevert(Rewards.InvalidBatchStructure.selector);
        rewards.mintBatchReward(rewardsBatch, signature);
    }

    function testDigestReward() public {
        bytes32 hashedEIP712DomainType =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 hashedName = keccak256(bytes("rewards.depin.nodle"));
        bytes32 hashedVersion = keccak256(bytes("1"));
        bytes32 domainSeparator =
            keccak256(abi.encode(hashedEIP712DomainType, hashedName, hashedVersion, block.chainid, address(rewards)));

        Rewards.Reward memory reward = Rewards.Reward(recipient, 100, 0);
        bytes32 structHash =
            keccak256(abi.encode(rewards.REWARD_TYPE_HASH(), reward.recipient, reward.amount, reward.sequence));

        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        assertEq(rewards.digestReward(reward), digest);
    }

    function testMintRewardInvalidDigest() public {
        bytes32 hashedEIP712DomainType =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 hashedName = keccak256(bytes("rewards.depin.nodle"));
        bytes32 hashedVersion = keccak256(bytes("2")); // Wrong version
        bytes32 domainSeparator =
            keccak256(abi.encode(hashedEIP712DomainType, hashedName, hashedVersion, block.chainid, address(rewards)));

        Rewards.Reward memory reward = Rewards.Reward(recipient, 100, 0);
        bytes32 structHash =
            keccak256(abi.encode(rewards.REWARD_TYPE_HASH(), reward.recipient, reward.amount, reward.sequence));

        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert();
        rewards.mintReward(reward, signature);
    }

    function testMintBatchRewardInvalidDigest() public {
        bytes32 hashedEIP712DomainType =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 hashedName = keccak256(bytes("rewards.depin.nodle"));
        bytes32 hashedVersion = keccak256(bytes("2")); // Wrong version
        bytes32 domainSeparator =
            keccak256(abi.encode(hashedEIP712DomainType, hashedName, hashedVersion, block.chainid, address(rewards)));

        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        recipients[0] = address(11);
        recipients[1] = address(22);
        amounts[0] = 100;
        amounts[1] = 200;

        bytes32 receipentsHash = keccak256(abi.encodePacked(recipients));
        bytes32 amountsHash = keccak256(abi.encodePacked(amounts));
        bytes32 structHash = keccak256(abi.encode(rewards.BATCH_REWARD_TYPE_HASH(), receipentsHash, amountsHash, 0));
        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert();
        rewards.mintBatchReward(Rewards.BatchReward(recipients, amounts, 0), signature);
    }

    function testRewardsClaimedResetsOnNewPeriod() public {
        Rewards.Reward memory reward = Rewards.Reward(recipient, 100, 0);
        bytes memory signature = createSignature(reward, oraclePrivateKey);
        rewards.mintReward(reward, signature);

        uint256 firstRenewal = block.timestamp + RENEWAL_PERIOD;
        uint256 fourthRenewal = firstRenewal + 3 * RENEWAL_PERIOD;
        uint256 fifthRenewal = firstRenewal + 4 * RENEWAL_PERIOD;
        uint256 sixthRenewal = firstRenewal + 5 * RENEWAL_PERIOD;

        assertEq(rewards.claimed(), 100);
        assertEq(rewards.quotaRenewalTimestamp(), firstRenewal);

        vm.warp(fourthRenewal + 1 seconds);

        reward = Rewards.Reward(recipient, 50, 1);
        signature = createSignature(reward, oraclePrivateKey);
        rewards.mintReward(reward, signature);

        assertEq(rewards.claimed(), 50);
        assertEq(rewards.quotaRenewalTimestamp(), fifthRenewal);

        vm.warp(fifthRenewal + 1 seconds);

        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        recipients[0] = address(11);
        recipients[1] = address(22);
        amounts[0] = 100;
        amounts[1] = 200;
        Rewards.BatchReward memory rewardsBatch = Rewards.BatchReward(recipients, amounts, 0);
        bytes memory batchSignature = createBatchSignature(rewardsBatch, oraclePrivateKey);
        rewards.mintBatchReward(rewardsBatch, batchSignature);
        assertEq(rewards.claimed(), 300);
        assertEq(rewards.quotaRenewalTimestamp(), sixthRenewal);
    }

    function testRewardsClaimedAccumulates() public {
        address user1 = address(11);
        address user2 = address(22);
        address user3 = address(33);

        Rewards.Reward memory reward = Rewards.Reward(user1, 3, 0);
        bytes memory signature = createSignature(reward, oraclePrivateKey);
        rewards.mintReward(reward, signature);

        reward = Rewards.Reward(user2, 5, 0);
        signature = createSignature(reward, oraclePrivateKey);
        rewards.mintReward(reward, signature);

        reward = Rewards.Reward(user1, 7, 1);
        signature = createSignature(reward, oraclePrivateKey);
        rewards.mintReward(reward, signature);

        reward = Rewards.Reward(user2, 11, 1);
        signature = createSignature(reward, oraclePrivateKey);
        rewards.mintReward(reward, signature);

        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        recipients[0] = user3;
        recipients[1] = user1;
        amounts[0] = 3;
        amounts[1] = 1;
        Rewards.BatchReward memory rewardsBatch = Rewards.BatchReward(recipients, amounts, 0);
        bytes memory batchSignature = createBatchSignature(rewardsBatch, oraclePrivateKey);
        rewards.mintBatchReward(rewardsBatch, batchSignature);

        assertEq(rewards.claimed(), 30);
    }

    function createSignature(Rewards.Reward memory reward, uint256 privateKey) internal view returns (bytes memory) {
        bytes32 digest = rewards.digestReward(reward);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function createBatchSignature(Rewards.BatchReward memory rewardsBatch, uint256 privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = rewards.digestBatchReward(rewardsBatch);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
