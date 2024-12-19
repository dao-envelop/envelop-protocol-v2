// SPDX-License-Identifier: MIT
// ENVELOP(NIFTSY) protocol V2 for NFT . 
pragma solidity ^0.8.28;
//import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IMyshchWalletwNFT {

	function erc20TransferWithRefund(
        address _target,
        address _receiver,
        uint256 _amount
    ) 
        external; 
        //ifUnlocked()
        //onlyWnftOwner()
         
    function setGasCheckPoint() external returns (uint256);
    function getRefund() external  returns (uint256 send); 
}