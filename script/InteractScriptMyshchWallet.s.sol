// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;
import {MyShchFactory} from "../src/MyShchFactory.sol";
import "../lib/forge-std/src/StdJson.sol";
import {Script, console2} from "forge-std/Script.sol";

// Test tx acions
contract InteractScriptMyshchWallet is Script {
    using stdJson for string;

    
    function run() public {
        MyShchFactory myshch_factory = MyShchFactory(0xf58208676a7b5a604df41ca25b5310f3cc997bF3);

        vm.startBroadcast();
        bytes memory botSignature;
        uint64 tgId = 5640708990;
        
        botSignature = hex"8e5efff53139fd93657ddc40f6ae9d22e19b88856a0a29f8901823ec3fa3171841bcecef6343aeb545ea14055666b808aa92a804585ab8a0073f18faf62212c71b";
        address payable customWallet = payable(myshch_factory.mintPersonalMSW(tgId, botSignature));

        vm.stopBroadcast();
    }
}
