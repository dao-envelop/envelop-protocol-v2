// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {MockERC1155} from "../src/mock/MockERC1155.sol";
import "../src/impl/WNFTLegacy721.sol";
import "../src/EnvelopLegacyWrapperBaseV2.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// call wrapBatch
contract LegacyWrapper_a_01 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    uint256 timelock = 10000;
    MockERC721 public erc721;
    MockERC20 public erc20;
    MockERC1155 public erc1155;
    EnvelopWNFTFactory public factory;
    WNFTLegacy721 public impl_legacy;
    EnvelopLegacyWrapperBaseV2 public wrapper;


    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC721');
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
        erc1155 = new MockERC1155('api.envelop.is');
        factory = new EnvelopWNFTFactory();
        wrapper = new EnvelopLegacyWrapperBaseV2(address(factory));
        impl_legacy = new WNFTLegacy721();
        factory.setWrapperStatus(address(wrapper), true); // set wrapper
        wrapper.setWNFTId(
            ET.AssetType.ERC721, 
            address(impl_legacy), 
            impl_legacy.TOKEN_ID()
        );
    }
    
    function test_create_legacy() public {
        
        address[] memory receivers = new address[](1);
        receivers[0] = address(1);
        ET.AssetItem memory original_nft = ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0);
        EnvelopLegacyWrapperBaseV2.INData memory inData = EnvelopLegacyWrapperBaseV2.INData(
                original_nft, // inAsset
                address(1), //unWrapDestination
                new ET.Fee[](0), // fees 
                new ET.Lock[](0), // locks
                new ET.Royalty[](0), // royalties
                ET.AssetType.ERC721,
                uint256(0),        
                0x0000   //bytes2
        );

        EnvelopLegacyWrapperBaseV2.INData[] memory inDataS = new  EnvelopLegacyWrapperBaseV2.INData[](2);
        inDataS[0] = inData;
        inDataS[1] = inData;

        ET.AssetItem[] memory collateral = new ET.AssetItem[](2);
        collateral[0] = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)),0,sendEtherAmount);
        collateral[1] = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)),0,sendEtherAmount);


        
        /*(bool sent, bytes memory data) = address(1).call{value: sendEtherAmount}("");
        // suppress solc warnings 
        sent;
        data;*/

        
        erc20.approve(address(wrapper), sendERC20Amount * 2);
        vm.expectRevert('Array params must have equal length');
        wrapper.wrapBatch(
            inDataS,
            collateral,   // collateral
            receivers
        );

        address[] memory receivers1 = new address[](2);
        receivers1[0] = address(1);
        receivers1[1] = address(2);

        wrapper.wrapBatch{value: sendEtherAmount}(
            inDataS,
            collateral,   // collateral
            receivers1
        );

        /*vm.stopPrank();
        address payable _wnftWallet = payable(wnftAsset.asset.contractAddress);
        assertEq(_wnftWallet.balance, sendEtherAmount);
        console2.log(_wnftWallet);

        
        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);

        vm.prank(address(1));
        ET.AssetItem[] memory assets = new ET.AssetItem[](1);
        assets[0] = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)),0,sendEtherAmount);
        wnft.unWrap(assets);
        assertEq(address(1).balance, sendEtherAmount);*/
    }
}