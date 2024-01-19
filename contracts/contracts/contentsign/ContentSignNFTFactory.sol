// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.20;

import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";

import "./ContentSignNFT.sol";

contract ContentSignNFTFactory {
    function deployContentSignNFT(
        bytes32 _salt,
        address _defaultAdmin,
        address _defaultMinter
    ) external returns (address) {
        ContentSignNFT nft = new ContentSignNFT{salt: _salt}(_defaultAdmin, _defaultMinter);
        return address(nft);
    }
}
