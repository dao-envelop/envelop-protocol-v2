// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/impl/WNFTV2Envelop721.sol";



contract InteracteScript_eth is Script {
    using stdJson for string;

    address payable impl = payable(address(0x3bfD12a303a41A6b31bB62Af90657B0b53EB6EfC));
        
    WNFTV2Envelop721 implIndex = WNFTV2Envelop721(impl);


    function run() public {
       
        vm.startBroadcast();
        bytes memory _data = "";
        implIndex.executeEncodedTx(address(0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E), 10000000, _data);
        vm.stopBroadcast();

    }
}