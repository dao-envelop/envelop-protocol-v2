// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTV2Envelop721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// call executeEncodedTxBatch with timelock
contract WNFTV2Envelop721_Test_a_05 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    MockERC721 public erc721;
    MockERC20 public erc20;
    EnvelopWNFTFactory public factory;
    WNFTV2Envelop721 public impl_legacy;

    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(impl_legacy), true); // set wrapper
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
    }


    function test_create_wNFT() public {
        uint256[] memory numberParams = new uint256[](1);
        numberParams[0] = block.timestamp + 10000;
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            address(this),
            'Envelop',
            'ENV',
            'https://api.envelop.is/',
            new address[](0),
            new bytes32[](0),
            numberParams,
            ""
            );

        vm.prank(address(this));
        address payable _wnftWallet = payable(impl_legacy.createWNFTonFactory(initData));

        // send erc20 to wnft wallet
        erc20.transfer(_wnftWallet, sendERC20Amount);
        
        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWallet);
        
        bytes memory _data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(11), sendERC20Amount / 2
        );

        address[] memory targets = new address[](2);
        targets[0] = address(erc20);
        targets[1] = address(erc20);

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        bytes[] memory datas = new bytes[](2);
        datas[0] = _data;
        datas[1] = _data;

        // now time lock
        vm.expectRevert('TimeLock error');
        wnft.executeEncodedTxBatch(targets, values, datas);
        
        // time lock has finished
        vm.warp(block.timestamp + 10001);
        vm.prank(address(1));
        vm.expectRevert('Only for wNFT owner');
        wnft.executeEncodedTxBatch(targets, values, datas);

        wnft.executeEncodedTxBatch(targets, values, datas);
        assertEq(erc20.balanceOf(address(11)), sendERC20Amount);
        assertEq(erc20.balanceOf(address(_wnftWallet)), 0);
    }
}