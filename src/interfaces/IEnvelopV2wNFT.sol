// SPDX-License-Identifier: MIT
// ENVELOP(NIFTSY) protocol V2 for NFT . 
pragma solidity ^0.8.20;

interface IEnvelopV2wNFT {

	event EnvelopV2OracleType(uint256 indexed oracleType, string contractName);

	function INITIAL_SIGN_STR() external view returns(string memory);
	function ORACLE_TYPE() external view returns(uint256);
	function SUPPORTED_RULES() external pure returns(bytes2); 

}