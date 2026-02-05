// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/utils/Predicter.sol";

/// @notice Deployment script for ChainlinkOracleAndVRF_DirectFunding on Arbitrum One.
contract DeployPredicter is Script {
    address public oracle;
    
    function run() external {
        if (block.chainid == 42161) {
            oracle = 0x32A676146bCF15397285d4bCb0CcaBa8C64F415c;
        } 
  
        vm.startBroadcast();

        Predicter predicter = new Predicter(oracle, msg.sender);

        console2.log("Predicter deployed at:", address(predicter));

        vm.stopBroadcast();
    }
}

