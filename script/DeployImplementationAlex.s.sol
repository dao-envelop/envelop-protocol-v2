// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import "../src/impl/WNFTV2IndexForEvent01.sol";
import "../src/impl/WNFTV2Envelop721.sol";

/// @notice Deployment script for ChainlinkOracleAndVRF_DirectFunding on Arbitrum One.
contract DeployImplementationAlex is Script {
    
    EnvelopWNFTFactory factory;
    WNFTV2Envelop721 impl_native;
    
    function run() external {
        
  
        vm.startBroadcast();

        factory = new EnvelopWNFTFactory();
        WNFTV2IndexForEvent01 impl_index01 = new WNFTV2IndexForEvent01(address(factory));
        factory.setWrapperStatus(address(impl_index01), true); // set wrapper
        impl_native = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(impl_native), true); // set wrapper


        console2.log("factory: %s", address(factory));
        console2.log("index_impl: %s", address(impl_index01));
        console2.log("impl_native: %s", address(impl_native));

        vm.stopBroadcast();
    }
}

// forge script script/DeployImplementationAlex.s.sol:DeployImplementationAlex --rpc-url mainnet  --account secret2 --sender 0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E --verify --priority-gas-price 300000 --etherscan-api-key $ETHERSCAN_TOKEN --broadcast */