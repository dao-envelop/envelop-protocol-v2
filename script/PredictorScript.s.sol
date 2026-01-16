// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";
import "../src/utils/Predicter.sol";
import "../src/mock/MockOracle.sol";
import "../src/mock/MockERC20.sol";

/// Deploy and init actions
contract PredictorScript is Script {
    using stdJson for string;

    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        vm.startBroadcast();
        MockOracle oracle = MockOracle(0x60c0A71A991aAe273c4ACD017Bb03d4FfdFb4996);
        Predicter predicter = new Predicter(0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E, address(oracle));
        vm.stopBroadcast();
        console2.log("Initialisation finished");
        //console2.log("token = ", address(token));
        console2.log("oracle = ", address(oracle));
        console2.log("predicter = ", address(predicter));
    }
}


//forge script ./script/PredictorScript.s.sol:PredictorScript --rpc-url arbitrum  --account secret2 --sender 0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E --verify --priority-gas-price 300000 --etherscan-api-key $ARBISCAN_TOKEN --broadcast
