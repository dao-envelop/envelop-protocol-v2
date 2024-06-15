// SPDX-License-Identifier: MIT
// Envelop Factory for wNFT contracts

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clone.sol";

contract EnvelopWNFTFactory {

    function creatWNFT(address _implementation, bytes memory _initCallData) 
        external 
        payable 
        returns(address wnft) 
    {
    	wnft = Clones.clone(_implementation);

    }
	
}