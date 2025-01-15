// SPDX-License-Identifier: MIT
// NIFTSY protocol for NFT
pragma solidity ^0.8.20;

contract ReentrancyAttacker3 {

    address public immutable wnfAddress;
    bytes public signature;
    
    constructor(address _wnft) 
    {
        wnfAddress = _wnft;
    }

    receive() external payable virtual {
        (bool success, bytes memory data) = wnfAddress.delegatecall(
            abi.encodeWithSignature("executeEncodedTxBySignature(address,uint256,bytes,bytes)",
                address(this), 2e18,"", signature)
        );
    }


    function setSignature(bytes memory _signature) external {
        signature = _signature;
    }

    function claimEther(uint256 _eth) external {
        (bool success, bytes memory data) = wnfAddress.delegatecall(
            abi.encodeWithSignature("executeEncodedTxBySignature(address,uint256,bytes,bytes)",
                address(this), _eth,"", signature)
        );

    }
}


