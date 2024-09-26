// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {EnvelopLegacyWrapperBaseV2} from "../src/EnvelopLegacyWrapperBaseV2.sol";
import "../src/impl/WNFTLegacy721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";


contract Factory_Test_m_02 is Test {
    address public constant addr4 = 0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC;
    uint256 public sendEtherAmount = 1e18;
    EnvelopWNFTFactory public factory;
    WNFTLegacy721 public impl_legacy;
    EnvelopLegacyWrapperBaseV2 public wrapper;
    uint256 public nonce;

    receive() external payable virtual {}
    function setUp() public {
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTLegacy721();
        wrapper = new EnvelopLegacyWrapperBaseV2(address(factory));
        factory.setWrapperStatus(address(this), true); // set wrapper
        factory.setWrapperStatus(address(wrapper), true); // set wrapper
        wrapper.setWNFTId(
            ET.AssetType.ERC721, 
            address(impl_legacy), 
            impl_legacy.TOKEN_ID()
        );
    }

    function test_create_legacy_factory() public {
        //ET.WNFT memory wnftcheck;
        bytes memory initCallData = abi.encodeWithSignature(
            impl_legacy.INITIAL_SIGN_STR(),
            address(this), "LegacyWNFTNAME", "LWNFT", "https://api.envelop.is" ,
            ET.WNFT(
                ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0), // inAsset
                new ET.AssetItem[](0),   // collateral
                address(this), //unWrapDestination 
                new ET.Fee[](0), // fees
                new ET.Lock[](0), // locks
                new ET.Royalty[](0), // royalties
                0x0105   //bytes2
            ) 
        );  
        address wnftPredictedAddress = factory.predictDeterministicAddress(
            address(impl_legacy), // implementation address
            keccak256(abi.encode(nonce))
        );
        address payable  created = payable(factory.createWNFT(address(impl_legacy), initCallData, keccak256(abi.encode(nonce))));
        //created = payable(factory.createWNFT(address(impl_legacy), initCallData, keccak256(abi.encode(nonce))));
        assertNotEq(created, address(impl_legacy));
        assertEq(wnftPredictedAddress, created);

    }

    function test_create_legacy_wrapper() public {
        //ET.WNFT memory wnftcheck;
        EnvelopLegacyWrapperBaseV2.INData memory ind = EnvelopLegacyWrapperBaseV2.INData(
            ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0), // inAsset
            address(this), //unWrapDestination (unused)
            new ET.Fee[](0), // fees
            new ET.Lock[](0), // locks
            new ET.Royalty[](0), // royalties
            ET.AssetType.ERC721,
            0, // outbalance
            0x0105   //bytes2
        ); 
        ET.AssetItem[] memory _coll = new ET.AssetItem[](0); 
        
        ET.NFTItem memory nonce2  = wrapper.saltBase(ET.AssetType.ERC721);
        address wnftPredictedAddress = factory.predictDeterministicAddress(
            address(impl_legacy), // implementation address
            keccak256(abi.encode(nonce2))
        );
        ET.AssetItem  memory created = wrapper.wrap(ind, _coll, address(22));
        assertNotEq(created.asset.contractAddress, address(impl_legacy));
        assertEq(wnftPredictedAddress, created.asset.contractAddress);
    }

    function test_create_2_legacy_wrapper() public {
        //ET.WNFT memory wnftcheck;
        EnvelopLegacyWrapperBaseV2.INData memory ind = EnvelopLegacyWrapperBaseV2.INData(
            ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0), // inAsset
            address(this), //unWrapDestination (unused)
            new ET.Fee[](0), // fees
            new ET.Lock[](0), // locks
            new ET.Royalty[](0), // royalties
            ET.AssetType.ERC721,
            0, // outbalance
            0x0105   //bytes2
        ); 
        ET.AssetItem[] memory _coll = new ET.AssetItem[](0); 
        
        ET.NFTItem memory nonce2  = wrapper.saltBase(ET.AssetType.ERC721);
        address wnftPredictedAddress = factory.predictDeterministicAddress(
            address(impl_legacy), // implementation address
            keccak256(abi.encode(nonce2))
        );
        ET.AssetItem  memory created = wrapper.wrap(ind, _coll, address(22));
        assertNotEq(created.asset.contractAddress, address(impl_legacy));
        assertEq(wnftPredictedAddress, created.asset.contractAddress);

        created = wrapper.wrap{value: sendEtherAmount}(ind, _coll, address(22));
        assertEq(created.asset.contractAddress.balance, sendEtherAmount);

        //Address.sendValue(payable(created.asset.contractAddress), 77777777);

       
    }
}
