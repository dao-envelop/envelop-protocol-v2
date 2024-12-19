// SPDX-License-Identifier: MIT
// Envelop Factory for wNFT contracts

pragma solidity ^0.8.28;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IEnvelopV2wNFT.sol";
/*
 * @dev https://eips.ethereum.org/EIPS/eip-1167[EIP 1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 */
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
    

    function createWNFT(address _implementation, bytes memory _initCallData) 
        public 
        payable 
        onlyTrusted
        returns(address wnft) 
    {
    	wnft = _clone(_implementation, _initCallData);

        emit EnvelopV2Deployment(
            wnft, 
            _implementation,
            IEnvelopV2wNFT(_implementation).ORACLE_TYPE()
        );
    }

    function createWNFT(address _implementation, bytes memory _initCallData, bytes32 _salt) 
        public 
        payable 
        onlyTrusted
        returns(address wnft) 
    {
        wnft = _cloneDeterministic(_implementation, _initCallData, _salt);

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

    function _clone(address _implementation, bytes memory _initCallData) 
        internal 
        returns(address _contract)
    {
        _contract = Clones.clone(_implementation);

        // Initialize wNFT
        if (_initCallData.length > 0) {
            Address.functionCallWithValue(_contract, _initCallData, msg.value);
        }
        
    }

    function _cloneDeterministic(
        address _implementation, 
        bytes memory _initCallData, 
        bytes32 _salt
    ) 
        internal 
        returns(address _contract)
    {
        _contract = Clones.cloneDeterministic(_implementation, _salt);

        // Initialize wNFT
        if (_initCallData.length > 0) {
            Address.functionCallWithValue(_contract, _initCallData, msg.value);
        }
        
    }

    function _cloneDeterministic(
        address _implementation, 
        bytes memory _initCallData, 
        bytes32 _salt, 
        uint256 _valueDenominator
    ) 
        internal 
        returns(address _contract)
    {
        _contract = Clones.cloneDeterministic(_implementation, _salt);

        // Initialize wNFT
        if (_initCallData.length > 0) {
            Address.functionCallWithValue(_contract, _initCallData, msg.value /_valueDenominator);
        }
        
    }
}