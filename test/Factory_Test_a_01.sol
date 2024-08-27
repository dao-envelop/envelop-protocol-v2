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
        //ET.WNFT memory wnftcheck;
        bytes memory initCallData = abi.encodeWithSignature(
            impl_legacy.INITIAL_SIGN_STR(),
            address(this), // creator and owner 
            "LegacyWNFTNAME", 
            "LWNFT", 
            "https://api.envelop.is" ,
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

        address payable _wnftWallet = payable(factory.creatWNFT(address(impl_legacy), initCallData));
        assertNotEq(_wnftWallet, address(impl_legacy));

        // send eth to wnft wallet
        vm.prank(address(this));
        (bool sent, bytes memory data) = _wnftWallet.call{value: sendEtherAmount}("");
        // suppress solc warnings 
        sent;
        data;
        assertEq(address(_wnftWallet).balance, sendEtherAmount);
        
        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);
        
        vm.prank(address(this));
        //console2.log('owner = ', wnft.ownerOf(impl_legacy.TOKEN_ID()));
        //wnft.approve(address(2), impl_legacy.TOKEN_ID());
        wnft.setApprovalForAll(address(2), true);

        vm.prank(address(2));
        ET.AssetItem memory collateral = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)),0,sendEtherAmount);
        wnft.removeCollateral(collateral, address(2));
        assertEq(address(2).balance, sendEtherAmount);
        assertEq(address(_wnftWallet).balance, 0);
    }
}