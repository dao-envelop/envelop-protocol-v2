// SPDX-License-Identifier: MIT
// Envelop Factory for wNFT contracts

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IEnvelopV2wNFT.sol";

contract EnvelopWNFTFactory is  Ownable{
    
    mapping(address wrapper => bool isTrusted) public trustedWrappers;

    event EnvelopV2Deployment(
        address indexed proxy, 
        address indexed implementation,
        uint256 envelopOracleType
    );

    constructor ()
        Ownable(msg.sender)
    {

    }

    modifier onlyTrusted() { 
        require (trustedWrappers[msg.sender], "Only for Envelop Authorized"); 
        _; 
    }
    

    function creatWNFT(address _implementation, bytes memory _initCallData) 
        public 
        payable 
        onlyTrusted
        returns(address wnft) 
    {
    	wnft = Clones.clone(_implementation);

    	// Initialize wNFT
    	if (_initCallData.length > 0) {
    	    Address.functionCallWithValue(wnft, _initCallData, msg.value);
        }
        
        emit EnvelopV2Deployment(
            wnft, 
            _implementation,
            IEnvelopV2wNFT(_implementation).ORACLE_TYPE()
        );
    }

    function creatWNFT(address _implementation, bytes memory _initCallData, bytes32 _salt) 
        public 
        payable 
        onlyTrusted
        returns(address wnft) 
    {
        wnft = Clones.cloneDeterministic(_implementation, _salt);

        // Initialize wNFT
        if (_initCallData.length > 0) {
            Address.functionCallWithValue(wnft, _initCallData, msg.value);
        }

        emit EnvelopV2Deployment(
            wnft, 
            _implementation,
            IEnvelopV2wNFT(_implementation).ORACLE_TYPE()
        );
    }

    function predictDeterministicAddress(
        address implementation,
        bytes32 salt
    ) public view returns (address) {
        return Clones.predictDeterministicAddress(implementation, salt);
    }

    function setWrapperStatus(address _wrapper, bool _status) external onlyOwner {
        trustedWrappers[_wrapper] = _status;
    }
}