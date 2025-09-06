// SPDX-License-Identifier: MIT
// NIFTSY protocol for NFT
pragma solidity ^0.8.20;

import "../interfaces/IEnvelopV2wNFT.sol";

contract ReentrancyAttacker {
    address public wnfAddress;
    address public receiver;
    address public owner;

    constructor(address _wnft, address _receiver, address _owner) {
        wnfAddress = _wnft;
        receiver = _receiver;
        owner = _owner;
    }

    receive() external payable virtual {
        bytes memory _data = abi.encodeWithSignature("transferFrom(address,address,uint256)", owner, receiver, 1);
        IEnvelopV2wNFT(wnfAddress).executeEncodedTx(wnfAddress, 0, _data);
    }
}
