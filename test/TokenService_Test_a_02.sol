// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {MockERC20} from "../src/mock/MockERC20.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC1155} from "../src/mock/MockERC1155.sol";
import {MockTokenService} from "../src/mock/MockTokenService.sol";
import {ET} from "../src/utils/LibET.sol";

// ERC1155
contract TokenService_Test_a_02 is Test {
    uint256 public sendEtherAmount = 1e18;
    MockERC721 public erc721;
    MockERC1155 public erc1155;
    MockERC20 public erc20;
    MockTokenService public tokenService;
    address public _beneficiary = address(100);
    uint256 public _feePercent = 30000;
    uint256 tokenId = 0;
    uint256 price = 1e18;
    uint256 amount = 10e18;

    error UnSupportedAsset(ET.AssetItem asset);

    receive() external payable virtual {}

    function setUp() public {
        erc20 = new MockERC20("USDT", "USDT");
        erc721 = new MockERC721("Mock ERC721", "ERC");
        erc1155 = new MockERC1155("https://api.envelop.is/metadata/");
        tokenService = new MockTokenService();
    }

    function test_view_balance() public {
        //native tokens
        ET.AssetItem memory item = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)), 0, 0);

        address payable _receiver = payable(address(11));
        _receiver.transfer(amount);
        assertEq(tokenService.balanceOf(item, address(11)), amount);

        // erc20 tokens balance
        erc20.transfer(address(1), amount);
        assertEq(erc20.balanceOf(address(1)), amount);
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)), 0, amount);
        assertEq(tokenService.balanceOf(item, address(1)), amount);

        // erc721 token balance
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)), tokenId, 0);
        assertEq(erc721.balanceOf(address(this)), 1);
        assertEq(tokenService.balanceOf(item, address(this)), 1);

        // erc1155 token balance
        erc1155.mint(address(1), tokenId, 1);
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC1155, address(erc1155)), tokenId, 1);
        assertEq(erc1155.balanceOf(address(1), tokenId), 1);
        assertEq(tokenService.balanceOf(item, address(1)), 1);

        // unsupported type
        item = ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)), 0, 0);
        vm.expectRevert(abi.encodeWithSelector(UnSupportedAsset.selector, item));
        uint256 balance = tokenService.balanceOf(item, address(1));
        assertEq(balance, 0);
    }

    function test_view_owner() public view {
        //native tokens
        ET.AssetItem memory item = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)), 0, 0);
        assertEq(tokenService.ownerOf(item), address(0));

        // erc20 tokens owner
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)), 0, amount);
        assertEq(tokenService.ownerOf(item), address(0));

        // erc721 token owner
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)), tokenId, 0);
        assertEq(erc721.ownerOf(tokenId), address(this));
        assertEq(tokenService.ownerOf(item), address(this));

        // erc1155 token owner
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC1155, address(erc1155)), tokenId, 1);
        assertEq(tokenService.ownerOf(item), address(0));
    }

    function test_view_approve() public {
        //native tokens
        ET.AssetItem memory item = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)), 0, 0);
        assertEq(tokenService.isApprovedFor(item, address(this), address(1)), 0);

        // erc20 tokens approve
        erc20.approve(address(1), amount);
        assertEq(erc20.allowance(address(this), address(1)), amount);
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)), 0, amount);
        assertEq(tokenService.isApprovedFor(item, address(this), address(1)), amount);

        // erc721 token approve
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)), tokenId, 0);
        // simple approve
        erc721.approve(address(1), tokenId);
        assertEq(erc721.getApproved(tokenId), address(1));
        assertEq(tokenService.isApprovedFor(item, address(this), address(1)), 1);

        // set operator
        erc721.setApprovalForAll(address(1), true);
        assertEq(erc721.isApprovedForAll(address(this), address(1)), true);
        assertEq(tokenService.isApprovedFor(item, address(this), address(1)), 1);

        // erc1155 token approve
        erc1155.mint(address(1), tokenId, 1);
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC1155, address(erc1155)), tokenId, 1);
        erc1155.setApprovalForAll(address(1), true);
        assertEq(erc1155.isApprovedForAll(address(this), address(1)), true);
        assertEq(tokenService.isApprovedFor(item, address(this), address(1)), 1);

        // unsupported type
        item = ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)), 0, 0);
        vm.expectRevert(abi.encodeWithSelector(UnSupportedAsset.selector, item));
        uint256 balance = tokenService.isApprovedFor(item, address(this), address(1));
        assertEq(balance, 0);
    }
}
