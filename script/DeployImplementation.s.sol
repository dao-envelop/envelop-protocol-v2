// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "./Objects.s.sol";
import "../src/impl/WNFTV2IndexForEvent01.sol";

// Test tx acions
contract DeployImplementation is Script, Objects {
    using stdJson for string;

    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log("Deployer address: %s, " "\n native balance %s", msg.sender, msg.sender.balance);

        getChainParams();
        deployOrInstances(true); // true - instances only

        params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));
        string memory explorer_url = params_json_file.readString(string.concat(".", vm.toString(block.chainid)));

        vm.startBroadcast();

        WNFTV2IndexForEvent01 impl_index01 = new WNFTV2IndexForEvent01(address(factory));
        factory.setWrapperStatus(address(impl_index01), true); // set wrapper

        vm.stopBroadcast();
        console2.log("\n**WNFTV2IndexForEvent01** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_index01));
        console2.log("impl_index = WNFTV2IndexForEvent01.at('%s')", address(impl_index01));
    }
}
