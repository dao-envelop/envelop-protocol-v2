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
contract TokenService_Test_a_05 is Test {
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
        erc20 = new MockERC20('USDT', 'USDT');
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        erc1155 = new MockERC1155('https://api.envelop.is/metadata/');
        tokenService = new MockTokenService();
    }
    
    function test_transfer() public {
        //native tokens transfer
        ET.AssetItem memory item = ET.AssetItem(
            ET.Asset(ET.AssetType.NATIVE, address(0)),
            0,
            amount);

        address payable _receiver = payable(address(11));
        _receiver.transfer(amount);

        vm.prank(address(11));
        uint256 transferredBalance = tokenService.transferSafe{value: amount}(item, address(11), address(12));
        assertEq(address(11).balance, 0);
        assertEq(address(12).balance, amount);
        assertEq(transferredBalance, amount);

        // erc20 tokens transfer
        erc20.transfer(address(1), amount);
        assertEq(erc20.balanceOf(address(1)), amount);
        item = ET.AssetItem(
            ET.Asset(ET.AssetType.ERC20, address(erc20)),
            0,
            amount);
        vm.startPrank(address(1));
        erc20.approve(address(tokenService), amount);
        transferredBalance = tokenService.transferSafe(item, address(1), address(2));
        vm.stopPrank();
        assertEq(erc20.balanceOf(address(1)), 0);
        assertEq(erc20.balanceOf(address(2)), amount);
        assertEq(transferredBalance, amount);

        // erc721 token transfer
        item = ET.AssetItem(
            ET.Asset(ET.AssetType.ERC721, address(erc721)),
            tokenId,
            0);
        erc721.approve(address(tokenService), tokenId);
        transferredBalance = tokenService.transferSafe(item, address(this), address(1));
        assertEq(erc721.ownerOf(tokenId), address(1));
        assertEq(transferredBalance, 1);


        // erc1155 token transfer - 4 copies
        erc1155.mint(address(1),tokenId, 4);
        item = ET.AssetItem(
            ET.Asset(ET.AssetType.ERC1155, address(erc1155)),
            tokenId,
            4);
        vm.startPrank(address(1));
        erc1155.setApprovalForAll(address(tokenService), true);
        transferredBalance = tokenService.transferSafe(item, address(1), address(2));
        vm.stopPrank();
        assertEq(erc1155.balanceOf(address(1),tokenId), 0);
        assertEq(erc1155.balanceOf(address(2),tokenId), 4);
        assertEq(transferredBalance, 4);

        // unsupported type
        item = ET.AssetItem(
            ET.Asset(ET.AssetType.EMPTY, address(0)),
            0,
            0);
        vm.expectRevert(
            abi.encodeWithSelector(UnSupportedAsset.selector, item)
        );
        tokenService.transfer(item, address(1), address(2));
    }
}