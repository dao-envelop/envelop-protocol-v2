// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {MockERC1155} from "../src/mock/MockERC1155.sol";
import "../src/impl/WNFTLegacy721.sol";
import "../src/EnvelopLegacyWrapperBaseV2.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// call wrapBatch
contract LegacyWrapper_a_02 is Test {
    
    

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

        ET.AssetItem[] memory collateral = new ET.AssetItem[](1);
        collateral[0] = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)),0,sendERC20Amount);
        
        erc20.approve(address(wrapper), sendERC20Amount * 2);
        vm.expectRevert('Array params must have equal length');

        wrapper.wrapWithCustomMetaDataBatch(
            inDataS,
            collateral,   // collateral
            receivers,
            "ENV",
            "EN",
            "https://api1.envelop.is"
        );

        address[] memory receivers1 = new address[](2);
        receivers1[0] = address(1);
        receivers1[1] = address(2);

        /*ET.AssetItem[] memory wnfts = */
        vm.recordLogs();
        string memory baseURL = 'https://api1.envelop.is/';
        wrapper.wrapWithCustomMetaDataBatch{value: sendEtherAmount}(
            inDataS,
            collateral,   // collateral
            receivers1,
            "ENV",
            "EN",
            baseURL
        );
        // Log[] memory entries = vm.getRecordedLogs();
        
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        
        address wnftAddress1 =  address(uint160(uint256(logs[3].topics[2])));
        address wnftAddress2 = address(uint160(uint256(logs[10].topics[2])));

        address payable wnftAddressP1 = payable(wnftAddress1);
        address payable wnftAddressP2 = payable(wnftAddress2);

        assertEq(wnftAddress1.balance, sendEtherAmount / 2);
        assertEq(wnftAddress2.balance, sendEtherAmount / 2);
        assertEq(erc20.balanceOf(wnftAddress1), sendERC20Amount);
        assertEq(erc20.balanceOf(wnftAddress2), sendERC20Amount);
        WNFTLegacy721 wnft1 = WNFTLegacy721(wnftAddressP1);
        WNFTLegacy721 wnft2 = WNFTLegacy721(wnftAddressP2);
        assertEq(wnft1.ownerOf(impl_legacy.TOKEN_ID()), address(1));
        assertEq(wnft2.ownerOf(impl_legacy.TOKEN_ID()), address(2));

        string memory url1 = string(
            abi.encodePacked(
                baseURL,
                vm.toString(block.chainid),
                "/",
                vm.toString(wnftAddress1),
                "/",
                vm.toString(impl_legacy.TOKEN_ID())
            )
        );
        
        assertEq(vm.toUppercase(url1), vm.toUppercase(wnft1.tokenURI(impl_legacy.TOKEN_ID())));

        string memory url2 = string(
            abi.encodePacked(
                baseURL,
                vm.toString(block.chainid),
                "/",
                vm.toString(wnftAddress2),
                "/",
                vm.toString(impl_legacy.TOKEN_ID())
            )
        );
        
        assertEq(vm.toUppercase(url2), vm.toUppercase(wnft2.tokenURI(impl_legacy.TOKEN_ID())));
        
    }
}