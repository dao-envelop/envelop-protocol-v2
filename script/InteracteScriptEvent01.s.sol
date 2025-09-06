// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import "../src/impl/WNFTV2IndexForEvent01.sol";


contract InteracteScriptEvent01 is Script {
    using stdJson for string;

    // arbitrum
    address payable indexEvent01ImplAddress = payable(0xbded9C8C786727499f13261cC34b997dfa260538);
    address payable relayer = payable(0xf4139ff4C97d189Db6D7F57849CBe22fAacEc688);
    address _factory = 0xBDb5201565925AE934A5622F0E7091aFFceed5EB;
   
    address owner = 0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E;
    address niftsy = 0x120e49d7ab1EDc0bFBF509Fa8566ca5b5dCAAd40;
    address usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    
    WNFTV2IndexForEvent01 indexEvent01Impl = WNFTV2IndexForEvent01(indexEvent01ImplAddress);
    EnvelopWNFTFactory factory = EnvelopWNFTFactory(_factory);
    
    function run() public {
        uint256 startPrice = 10;
        uint256[] memory numberParams = new uint256[](2);
        numberParams[0] = 0;
        numberParams[1] = startPrice;
        WNFTV2IndexForEvent01.InitParams memory initData = WNFTV2Envelop721.InitParams(
            owner,
            "",
            "",
            "",
            new address[](0),
            new bytes32[](0),
            numberParams,
            ""
        );

        vm.startBroadcast();
        //address payable _wnftWallet2 = payable(impl_myshch.createWNFTonFactory(initData));
        address payable indexEvent01 = payable(indexEvent01Impl.createWNFTonFactory(initData));
        IERC20(niftsy).transfer(indexEvent01, 1e18);
        IERC20(usdt).transfer(indexEvent01, 50000);
        vm.stopBroadcast();
    }
}
