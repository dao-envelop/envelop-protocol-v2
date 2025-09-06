// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {MockERC1155} from "../src/mock/MockERC1155.sol";
import "../src/impl/WNFTLegacy721.sol";
import "../src/EnvelopLegacyWrapperBaseV2.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

contract Factory_Test_a_23 is Test {
    using Strings for uint160;

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
        erc721 = new MockERC721("Mock ERC721", "ERC721");
        erc20 = new MockERC20("Mock ERC20", "ERC20");
        erc1155 = new MockERC1155("api.envelop.is");
        factory = new EnvelopWNFTFactory();
        wrapper = new EnvelopLegacyWrapperBaseV2(address(factory));
        impl_legacy = new WNFTLegacy721();
        factory.setWrapperStatus(address(wrapper), true); // set wrapper
        wrapper.setWNFTId(ET.AssetType.ERC721, address(impl_legacy), impl_legacy.TOKEN_ID());
    }

    // call transferFrom wnft via executeEncodedTx
    // call removeCollateral via executeEncodedTx
    // call unWrap wnft via executeEncodedTx
    function test_executeEncodedTx() public {
        uint256 tokenId = 0;
        ET.AssetItem memory original_nft = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)), tokenId, 0);
        EnvelopLegacyWrapperBaseV2.INData memory inData = EnvelopLegacyWrapperBaseV2.INData(
            original_nft, // inAsset
            address(1), //unWrapDestination
            new ET.Fee[](0), // fees
            new ET.Lock[](0), // locks
            new ET.Royalty[](0), // royalties
            ET.AssetType.ERC721,
            uint256(0),
            0x0000 //bytes2
        );

        erc721.setApprovalForAll(address(wrapper), true);
        ET.AssetItem memory wnftAsset = wrapper.wrap{value: sendEtherAmount}(
            inData,
            new ET.AssetItem[](0), // collateral
            address(1)
        );
        address payable _wnftWallet = payable(wnftAsset.asset.contractAddress);
        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);

        // try to transferFrom
        erc20.transfer(_wnftWallet, sendERC20Amount);
        bytes memory _data = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)", address(1), address(2), impl_legacy.TOKEN_ID()
        );

        vm.prank(address(1));
        vm.expectRevert();
        wnft.executeEncodedTx(_wnftWallet, 0, _data);

        vm.startPrank(address(1));
        wnft.setApprovalForAll(_wnftWallet, true);
        wnft.executeEncodedTx(_wnftWallet, 0, _data);
        vm.stopPrank();
        assertEq(wnft.ownerOf(impl_legacy.TOKEN_ID()), address(2));

        // try to remove collateral

        /*ET.AssetItem memory collateral = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)),0, sendERC20Amount / 2);
        _data = abi.encodeWithSignature(
            "removeCollateral(((uint8,address),uint256,uint256),address)",

            collateral, address(2)
        );*/
        ET.AssetItem memory collateral = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)), 0, sendERC20Amount);
        ET.AssetItem[] memory collaterals = new ET.AssetItem[](1);
        collaterals[0] = collateral;

        _data = abi.encodeWithSignature("unWrap(((uint8,address),uint256,uint256)[])", collaterals);

        vm.expectRevert();
        wnft.executeEncodedTx(_wnftWallet, 0, _data);
        vm.startPrank(address(2));
        wnft.setApprovalForAll(_wnftWallet, true);
        wnft.executeEncodedTx(_wnftWallet, 0, _data);
        vm.stopPrank();

        console2.log(erc20.balanceOf(_wnftWallet));
        assertEq(erc20.balanceOf(_wnftWallet), sendERC20Amount);
    }
}
