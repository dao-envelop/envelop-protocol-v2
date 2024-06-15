// SPDX-License-Identifier: MIT
// Envelop Factory for wNFT contracts

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract EnvelopWNFTFactory {
    

    event EnvelopV2wNFTCreated();
    function creatWNFT(address _implementation, bytes memory _initCallData) 
        public 
        payable 
        returns(address wnft) 
    {
    	// TODO Checks of implementation, caller and calldata(?)
    	wnft = Clones.clone(_implementation);

    	// Initialize wNFT
    	if (_initCallData.length > 0) {
    	    Address.functionCallWithValue(wnft, _initCallData, msg.value);
        }
    }
	
}