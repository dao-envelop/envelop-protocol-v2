// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import "../src/impl/WNFTLegacy721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";


contract Factory_Test_a_01 is Test {
    uint256 public sendEtherAmount = 1e18;
    MockERC721 public erc721;
    EnvelopWNFTFactory public factory;
    WNFTLegacy721 public impl_legacy;

    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTLegacy721();
    }
    
    function test_create_legacy() public {
        ET.WNFT memory wnftcheck;
        bytes memory initCallData = abi.encodeWithSignature(
            impl_legacy.INITIAL_SIGN_STR(),
            address(1), "LegacyWNFTNAME", "LWNFT", "https://api.envelop.is" ,
            //new ET.WNFT[](1)[0]
            ET.WNFT(
                ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0), // inAsset
                new ET.AssetItem[](0),   // collateral
                address(this), //unWrapDestination 
                new ET.Fee[](0), // fees
                new ET.Lock[](0), // locks
                new ET.Royalty[](0), // royalties
                0xffff   //bytes2
            ) 
        );  
        // console2.log(string(initCallData));
        // (
        //     address a, 
        //     string memory n1, 
        //     string memory n2, 
        //     string memory n3 //,  
        //     //ET.WNFT memory k
        // ) =  abi.decode(
        //     initCallData,
        //     (address, string, string, string)
        // );
        //{value: sendEtherAmount}

        address payable wnftWallet = payable(factory.creatWNFT(address(impl_legacy), initCallData));
        assertNotEq(wnftWallet, address(impl_legacy));

        // send eth to wnft wallet
        vm.prank(address(this));
        (bool sent, bytes memory data) = wnftWallet.call{value: sendEtherAmount}("");
        // suppress solc warnings 
        sent;
        data;
        assertEq(address(wnftWallet).balance, sendEtherAmount);
        
        wnftWallet.approve(address(1), impl_legacy.TOKEN_ID());
        
    }
}