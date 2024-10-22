// SPDX-License-Identifier: MIT
// Myshch Factory for Envelop wNFT contracts
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {EnvelopWNFTFactory} from "./EnvelopWNFTFactory.sol";

contract MyShchFactory is EnvelopWNFTFactory {
	function mintPersonalMSW(uint64 _tgId, bytes calldata _signature) 
	    external 
	    returns(address wnft)
	{

	}
}