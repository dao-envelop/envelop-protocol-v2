// SPDX-License-Identifier: MIT
// ENVELOP(NIFTSY) protocol V2 for NFT . 
pragma solidity ^0.8.20;

interface IEnvelopWNFTFactory {

    function createWNFT(address _implementation, bytes memory _initCallData) 
        external 
        payable 
        returns(address wnft); 


    function createWNFT(address _implementation, bytes memory _initCallData, bytes32 _salt) 
        external 
        payable 
        returns(address wnft); 
    
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt
    ) external view returns (address);

    function setWrapperStatus(address _wrapper, bool _status) external;
}