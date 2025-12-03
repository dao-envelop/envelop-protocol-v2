// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/utils/EnvelopOracle.sol";

/// @notice Deployment script for ChainlinkOracleAndVRF_DirectFunding on Arbitrum One.
contract DeployEnvelopOracle_Arb is Script {
     address public feedRegistry;

    function run() external {
        if (block.chainid == 1) {
            feedRegistry = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf;
        }
  
        vm.startBroadcast();

        EnvelopOracle oracle = new EnvelopOracle(feedRegistry, 3600);

        console2.log("EnvelopOracle deployed at:", address(oracle));

        vm.stopBroadcast();
    }
}

