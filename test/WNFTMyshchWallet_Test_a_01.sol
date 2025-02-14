// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import "../src/impl/WNFTV2Envelop721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// call erc20TransferWithRefund
// owner of admin wnft wallet call function
// user wnft wallet gets erc20 tokens and send eth for tx

contract WNFTMyshchWallet_Test_a_01 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    MockERC721 public erc721;
    MockERC20 public erc20;
    EnvelopWNFTFactory public factory;
    WNFTMyshchWallet public impl_myshch;

    address payable _wnftWalletBot;
    address payable _wnftWalletUser;

    receive() external payable virtual {}
    
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
        impl_myshch = new WNFTMyshchWallet(address(factory));
        factory.setWrapperStatus(address(impl_myshch), true); // set wrapper
        erc20 = new MockERC20('Mock ERC20', 'ERC20');

        // create admin wnft wallet
        address[] memory addrs1 = new address[](0);
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            address(this),
            'Envelop',
            'ENV',
            'https://api.envelop.is/',
            addrs1,
            new bytes32[](0),
            new uint256[](0),
            ""
        );

        vm.prank(address(this));
        _wnftWalletBot = payable(impl_myshch.createWNFTonFactory(initData));

        // create user wnft wallet
        address[] memory addrs2 = new address[](1);
        addrs2[0] = _wnftWalletBot;  // add relayer
        initData = WNFTV2Envelop721.InitParams(
            address(1), // user address
            'Envelop',
            'ENV',
            'https://api.envelop.is/',
            addrs2,
            new bytes32[](0),
            new uint256[](0),
            ""
        );
        vm.prank(address(this));
        _wnftWalletUser = payable(impl_myshch.createWNFTonFactory(initData));

    }
    
    /*function test_create_wnft() public {
        
        WNFTMyshchWallet wnftBot = WNFTMyshchWallet(_wnftWalletBot);

        // send erc20 to wnft wallet
        erc20.transfer(_wnftWalletBot, sendERC20Amount);
        
        //WNFTMyshchWallet wnftUser = WNFTMyshchWallet(_wnftWalletUser);

        wnftBot.setApprovalForAll(address(2), true);

        //send eth to user wnft wallet
        _wnftWalletUser.transfer(sendEtherAmount);
        console2.log(address(2).balance);
        console2.log(_wnftWalletUser.balance);
        vm.prank(address(2));
        vm.txGasPrice(2);
        wnftBot.erc20TransferWithRefund(address(erc20), _wnftWalletUser, sendERC20Amount);
        VmSafe.Gas memory gasInfo = vm.lastCallGas();
        console2.log(gasInfo.gasTotalUsed);
        console2.log(address(2).balance);
        console2.log(_wnftWalletUser.balance);
    }

    function test_check_setGasCheckPoint() public {
        
        WNFTMyshchWallet wnftBot = WNFTMyshchWallet(_wnftWalletBot);

        vm.expectRevert("Only for approved relayer");
        wnftBot.setGasCheckPoint();

        wnftBot.setRelayerStatus(address(this), true);
        wnftBot.setGasCheckPoint();
        assertGt(wnftBot.gasLeftOnStart(),0);

        vm.prank(address(1));
        vm.expectRevert('Only for wNFT owner');
        wnftBot.setRelayerStatus(address(1), true);
    }

    function test_check_getRefund() public {
        
        WNFTMyshchWallet wnftBot = WNFTMyshchWallet(_wnftWalletBot);

        vm.expectRevert("Only for approved relayer");
        wnftBot.getRefund();

        wnftBot.setRelayerStatus(address(1), true);
        assertEq(wnftBot.getRelayerStatus(address(1)), true);
        vm.prank(address(1));
        wnftBot.setGasCheckPoint();
        assertGt(wnftBot.gasLeftOnStart(),0);

        vm.prank(address(1));
        vm.txGasPrice(2);
        vm.expectRevert();
        wnftBot.getRefund();

        _wnftWalletBot.transfer(sendEtherAmount);

        console2.log(address(1).balance);
        vm.txGasPrice(2);
        vm.prank(address(1));
        wnftBot.getRefund();
        console2.log(address(1).balance);
    }*/

    function test_check_getRefund_1() public {
        
        WNFTMyshchWallet wnftBot = WNFTMyshchWallet(_wnftWalletBot);

        _wnftWalletUser.call{value: sendEtherAmount}(""); // send eth to _wnftWalletUser
        erc20.transfer(_wnftWalletBot, 5 * sendERC20Amount);

        address[] memory targets = new address[](7);
        bytes[] memory dataArray = new bytes[](7);
        uint256[] memory values = new uint256[](7);

        targets[0] = address(_wnftWalletUser);
        targets[1] = address(address(erc20));
        targets[2] = address(address(erc20));
        targets[3] = address(address(erc20));
        targets[4] = address(address(erc20));
        targets[5] = address(address(erc20));
        targets[6] = address(_wnftWalletUser);

        
        dataArray[0] = abi.encodeWithSignature(
            "setGasCheckPoint()"
        );
        dataArray[1] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(1), sendERC20Amount
        );
        dataArray[2] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(1), sendERC20Amount
        );
        dataArray[3] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(1), sendERC20Amount
        );
        dataArray[4] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(1), sendERC20Amount
        );
        dataArray[5] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(1), sendERC20Amount
        );
        dataArray[6] = abi.encodeWithSignature(
            "getRefund()"
        );
        
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        values[4] = 0;
        values[5] = 0;
        values[6] = 0;

        vm.txGasPrice(2);
        console2.log('wnftUser.balance before = ', _wnftWalletUser.balance);
        console2.log('wnftBot.balance before = ', _wnftWalletBot.balance);
        console2.log('this.balance before = ', address(this).balance);
        vm.expectRevert('Too much refund request');
        bytes[] memory result = wnftBot.executeEncodedTxBatch(targets, values, dataArray);
        console2.log('wnftUser.balance after = ', _wnftWalletUser.balance);
        console2.log('wnftBot.balance after = ', _wnftWalletBot.balance);
        console2.log('this.balance after = ', address(this).balance);
    }
}