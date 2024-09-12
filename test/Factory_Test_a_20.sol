// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC1155} from "../src/mock/MockERC1155.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTLegacy721.sol";
import "../src/EnvelopLegacyWrapperBaseV2.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// try to withdraw original nft - erc1155
// before add in collateral same nft like original nt
contract Factory_Test_a_20 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    uint256 timelock = 10000;
    MockERC721 public erc721;
    MockERC1155 public erc1155;
    MockERC20 public erc20;
    EnvelopWNFTFactory public factory;
    WNFTLegacy721 public impl_legacy;
    EnvelopLegacyWrapperBaseV2 public wrapper;

    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC721');
        erc1155 = new MockERC1155('api.envelop.is');
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
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
        vm.prank(address(1));
        erc1155.mint(address(1), tokenId, amount);
        erc1155.mint(address(1), tokenId + 1, amount);

        ET.AssetItem memory original_nft = ET.AssetItem(ET.Asset(ET.AssetType.ERC1155, address(erc1155)),tokenId,amount);
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
        
        vm.startPrank(address(1));
        erc1155.setApprovalForAll(address(wrapper),true);
        ET.AssetItem memory wnftAsset = wrapper.wrap(
            inData,
            new ET.AssetItem[](0),   // collateral
            address(1)
        );
        vm.stopPrank();
        
        address payable _wnftWallet = payable(wnftAsset.asset.contractAddress);
        assertEq(erc1155.balanceOf(_wnftWallet,tokenId), amount);

        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);

        // add collateral
        vm.prank(address(1));
        erc1155.safeTransferFrom(address(1), _wnftWallet, tokenId + 1, amount, bytes(""));
        
        // try to withdraw original NFT ERC1155 - revert
        vm.prank(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(WNFTLegacy721.InsufficientCollateral.selector, original_nft, 0)
        );
        wnft.removeCollateral(original_nft, address(1));

        // try to removeCollateralBatch original nft - revert
        ET.AssetItem[] memory assets = new ET.AssetItem[](1);
        assets[0] = original_nft;
        vm.prank(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(WNFTLegacy721.InsufficientCollateral.selector, original_nft, 0)
        );
        wnft.removeCollateralBatch(assets, address(1));

        // try to executeEncodedTx original nft - revert
        bytes memory _data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            _wnftWallet, address(11), tokenId, amount, bytes('')
        );

        vm.prank(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(WNFTLegacy721.InsufficientCollateral.selector, original_nft, 0)
        );
        wnft.executeEncodedTx(address(erc1155), 0, _data);

        // try to executeEncodedTx original nft - revert
        address[] memory targets = new address[](1);
        bytes[] memory dataArray = new bytes[](1);
        uint256[] memory values = new uint256[](1);

        targets[0] = address(erc1155);
        dataArray[0] = _data;
        values[0] = 0;

        vm.prank(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(WNFTLegacy721.InsufficientCollateral.selector, original_nft, 0)
        );
        wnft.executeEncodedTxBatch(targets, values, dataArray);

        // try to unwrap with original nft inside
        vm.prank(address(1));
        ET.AssetItem[] memory colAssets = new ET.AssetItem[](1);
        colAssets[0] = ET.AssetItem(ET.Asset(ET.AssetType.ERC1155, address(erc1155)),tokenId + 1,amount);
        wnft.unWrap(colAssets);
        //assertEq(erc1155.balanceOf(address(1), tokenId), amount);
        //assertEq(erc1155.balanceOf(address(1), tokenId + 1), amount);
    }
}