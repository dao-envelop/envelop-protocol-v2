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

// try to withdraw original nft - erc721
// when same NFT in collateral (same nft smart contract)
contract Factory_Test_a_16 is Test {
    
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
        uint256 tokenId = 0;
        uint256 amount = 6;
        ET.AssetItem memory original_nft = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)),tokenId,0);
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
        
        erc721.transferFrom(address(this), address(1),tokenId);
        erc20.transfer(address(1), sendERC20Amount);

        (bool sent, bytes memory data) = address(1).call{value: sendEtherAmount}("");
        // suppress solc warnings 
        sent;
        data;

        vm.startPrank(address(1));
        erc721.mint(address(1), tokenId + 1); 
        erc721.mint(address(1), tokenId + 2);
        erc1155.mint(address(1), tokenId, amount);
        // make approve
        erc20.approve(address(wrapper), sendERC20Amount);
        erc721.setApprovalForAll(address(wrapper), true);
        erc1155.setApprovalForAll(address(wrapper), true);

        // try to unwrap with original nft inside and erc721 collateral
        ET.AssetItem[] memory colAssets = new ET.AssetItem[](5);
        colAssets[0] = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)),tokenId + 1,0);
        colAssets[1] = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)),tokenId + 2,0);
        colAssets[2] = ET.AssetItem(ET.Asset(ET.AssetType.ERC1155, address(erc1155)),tokenId,amount);
        colAssets[3] = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)),0,sendERC20Amount);
        colAssets[4] = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)),0,sendEtherAmount);

        ET.AssetItem memory wnftAsset = wrapper.wrap{value: sendEtherAmount}(
            inData,
            colAssets,   // collateral
            address(1)
        );

        vm.stopPrank();
        address payable _wnftWallet = payable(wnftAsset.asset.contractAddress);
        assertEq(erc721.ownerOf(tokenId), _wnftWallet);
        assertEq(erc721.ownerOf(tokenId + 1), _wnftWallet);
        assertEq(erc20.balanceOf(_wnftWallet), sendERC20Amount);
        assertEq(_wnftWallet.balance, sendEtherAmount);
        assertEq(erc1155.balanceOf(_wnftWallet, tokenId), amount);
        
        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);

        vm.prank(address(1));
        wnft.unWrap(colAssets);
        assertEq(erc721.ownerOf(tokenId), address(1));
        assertEq(erc721.ownerOf(tokenId + 1), address(1));
        assertEq(erc721.ownerOf(tokenId + 2), address(1));
        assertEq(erc1155.balanceOf(address(1), tokenId), amount);
        assertEq(erc20.balanceOf(address(1)), sendERC20Amount);
        assertEq(address(1).balance, sendEtherAmount);

    }
}