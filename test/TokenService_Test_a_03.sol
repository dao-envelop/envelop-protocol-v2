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
contract TokenService_Test_a_03 is Test {
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

    function test_transferEmergency() public {
        //native tokens transfer
        ET.AssetItem memory item = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)), 0, amount);

        address payable _receiver = payable(address(111));
        _receiver.transfer(amount);

        vm.prank(address(111));
        bytes memory returndata = tokenService.transferEmergency{value: amount}(item, address(111), address(122));
        assertEq(address(111).balance, 0);
        assertEq(address(122).balance, amount);
        assertEq0(returndata, bytes(""));

        // erc20 tokens transfer
        erc20.transfer(address(1), amount);
        assertEq(erc20.balanceOf(address(1)), amount);
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)), 0, amount);
        vm.startPrank(address(1));
        erc20.approve(address(tokenService), amount);
        tokenService.transferEmergency(item, address(1), address(2));
        vm.stopPrank();
        assertEq(erc20.balanceOf(address(1)), 0);
        assertEq(erc20.balanceOf(address(2)), amount);

        // erc721 token transfer
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)), tokenId, 0);
        erc721.approve(address(tokenService), tokenId);
        tokenService.transferEmergency(item, address(this), address(1));
        assertEq(erc721.ownerOf(tokenId), address(1));

        // erc1155 token transfer
        erc1155.mint(address(1), tokenId, 1);
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC1155, address(erc1155)), tokenId, 1);
        vm.startPrank(address(1));
        erc1155.setApprovalForAll(address(tokenService), true);
        tokenService.transferEmergency(item, address(1), address(2));
        vm.stopPrank();
        assertEq(erc1155.balanceOf(address(1), tokenId), 0);
        assertEq(erc1155.balanceOf(address(2), tokenId), 1);

        // unsupported type
        item = ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)), 0, 0);
        vm.expectRevert(abi.encodeWithSelector(UnSupportedAsset.selector, item));
        tokenService.transferEmergency(item, address(1), address(2));
    }
}
