// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/utils/Predicter.sol";

/// @notice Deployment script for ChainlinkOracleAndVRF_DirectFunding on Arbitrum One.
contract DeployPredicter is Script {
    address public oracle;
    
    function run() external {
        if (block.chainid == 42161) {
            //oracle = 0x32A676146bCF15397285d4bCb0CcaBa8C64F415c;
            oracle = 0x60c0A71A991aAe273c4ACD017Bb03d4FfdFb4996;
        } 
  
        vm.startBroadcast();

        Predicter predicter = new Predicter(msg.sender);

        console2.log("Predicter deployed at:", address(predicter));

        vm.stopBroadcast();
    }
}

// forge script script/DeployPredicter.s.sol:DeployPredicter --rpc-url arbitrum  --account secret2 --sender 0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E --verify --priority-gas-price 300000 --etherscan-api-key $ETHERSCAN_TOKEN --broadcast