// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import "../src/impl/WNFTV2IndexForEvent01.sol";
//import "../src/impl/WNFTV2Envelop721.sol";
//import "../src/EnvelopLegacyWrapperBaseV2.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// add collateral to wnft (erc721, erc1155) and withdraw
contract WNFTV2Index_Test_m_01 is Test  {
    using Strings for uint160;
    using Strings for uint256;
    
    event Log(string message);

    uint256 timelock = 10000;
    EnvelopWNFTFactory public factory;
    WNFTV2IndexForEvent01 public impl_index;


    receive() external payable virtual {}
    function setUp() public {
        factory = new EnvelopWNFTFactory();
        impl_index = new WNFTV2IndexForEvent01(address(factory));
        factory.setWrapperStatus(address(impl_index), true); // set wrapper
    }

    function test_wNFTMaker() public {
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            address(this),
            'Envelop V2 Smart Wallet',
            'ENVELOPV2',
            'https://api.envelop.is/wallet',
            new address[](0),
            new bytes32[](0),
            //new uint256[](0),
            values,
            ""
            );

        address payable _wnftWallet = payable(impl_index.createWNFTonFactory(initData));

        WNFTV2IndexForEvent01 index1 = WNFTV2IndexForEvent01(_wnftWallet);

        assertEq(index1.name(), "Envelop V2 Indices for Competition");
        assertEq(index1.symbol(), "Indices 2025");
    }
}