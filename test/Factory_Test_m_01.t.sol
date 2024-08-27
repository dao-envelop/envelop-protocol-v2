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


contract Factory_Test_m_01 is Test {
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
    
    function test_create() public {
        bytes memory initCallData;
        address created = factory.creatWNFT(address(erc721), initCallData);
        MockERC721  erc721_clone = MockERC721(created);
        assertEq(erc721.CHECKED_NAME(), erc721_clone.CHECKED_NAME());
        assertNotEq(address(erc721), address(erc721_clone));
    }

    function test_create_legacy() public {
        ET.WNFT memory wnftcheck;
        bytes memory initCallData = abi.encodeWithSignature(
            impl_legacy.INITIAL_SIGN_STR(),
            address(this), "LegacyWNFTNAME", "LWNFT", "https://api.envelop.is" ,
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

        address payable  created = payable(factory.creatWNFT(address(impl_legacy), initCallData));
        assertNotEq(created, address(impl_legacy));

        WNFTLegacy721 wnft = WNFTLegacy721(created);
        wnft.ownerOf(1);
        //vm.prank(address(1));
        //wnft.transferFrom(address(this), address(1), impl_legacy.TOKEN_ID());
        wnft.approve(address(2), impl_legacy.TOKEN_ID());
        
    }
}
