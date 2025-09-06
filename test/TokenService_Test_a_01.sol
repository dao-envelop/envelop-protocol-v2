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
contract TokenService_Test_a_01 is Test {
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

    receive() external payable virtual {}

    function setUp() public {
        erc20 = new MockERC20("USDT", "USDT");
        erc721 = new MockERC721("Mock ERC721", "ERC");
        erc1155 = new MockERC1155("https://api.envelop.is/metadata/");
        tokenService = new MockTokenService();
    }

    function test_getTransferTxData() public {
        //native tokens
        ET.AssetItem memory item = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)), 0, 0);
        //console2.logBytes(tokenService.getTransferTxData(item, address(1), address(2)));
        //console2.logBytes(bytes(''));
        assertEq0(tokenService.getTransferTxData(item, address(1), address(2)), bytes(""));

        // erc20 tokens from tokenService
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)), 0, amount);
        erc20.transfer(address(tokenService), amount);
        bytes memory data = tokenService.getTransferTxData(item, address(tokenService), address(1));
        vm.prank(address(tokenService));
        bytes memory _returnData = Address.functionCall(address(erc20), data);
        console2.log(erc20.balanceOf(address(1)));
        assertEq(erc20.balanceOf(address(1)), amount);

        // erc20 tokens from address(1), spender address(this)
        vm.prank(address(1));
        erc20.approve(address(this), amount);
        data = tokenService.getTransferTxData(item, address(1), address(2));
        _returnData = Address.functionCall(address(erc20), data);
        console2.log(erc20.balanceOf(address(2)));
        assertEq(erc20.balanceOf(address(2)), amount);
        assertEq(erc20.balanceOf(address(1)), 0);

        // erc721 token from address(this)
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)), tokenId, 0);
        data = tokenService.getTransferTxData(item, address(this), address(1));
        _returnData = Address.functionCall(address(erc721), data);
        assertEq(erc721.ownerOf(tokenId), address(1));

        // erc1155 token from address(1), spender address(this)
        erc1155.mint(address(1), tokenId, 1);
        item = ET.AssetItem(ET.Asset(ET.AssetType.ERC1155, address(erc1155)), tokenId, 1);
        vm.prank(address(1));
        erc1155.safeTransferFrom(address(1), address(2), tokenId, 1, "");
        vm.startPrank(address(2));
        erc1155.setApprovalForAll(address(tokenService), true);
        //tokenService.transferEmergency(item, address(2), address(3));
        data = tokenService.getTransferTxData(item, address(2), address(3));
        _returnData = Address.functionCall(address(erc1155), data);
        vm.stopPrank();
        assertEq(erc1155.balanceOf(address(2), tokenId), 0);
        assertEq(erc1155.balanceOf(address(3), tokenId), 1);

        vm.startPrank(address(3));
        erc1155.setApprovalForAll(address(tokenService), true);
        tokenService.transferEmergency(item, address(3), address(4));
        vm.stopPrank();
        assertEq(erc1155.balanceOf(address(4), tokenId), 1);
    }
}
