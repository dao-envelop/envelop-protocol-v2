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

contract WNFTMyshchWallet_Test_m_01 is Test {
    
    event Log(string message);
    
    struct Bal {
        uint256 before;
        uint256 afterb;
    }

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    MockERC721 public erc721;
    MockERC20 public erc20;
    EnvelopWNFTFactory public factory;
    WNFTMyshchWallet public impl_myshch;

    address payable _wnftWallet1;  // bot
    address payable _wnftWallet2; // user
    
    Bal[] balances;
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
            'Envelop Bot',
            'ENV',
            'https://api.envelop.is/',
            addrs1,
            new bytes32[](0),
            new uint256[](0),
            ""
        );

        //vm.prank(address(this));
        _wnftWallet1 = payable(impl_myshch.createWNFTonFactory(initData));

        // create user wnft wallet
        address[] memory addrs2 = new address[](1);
        addrs2[0] = _wnftWallet1;  // add relayer
        uint256[] memory np =  new uint256[](2);
        np[1] = 10_000;

        initData = WNFTV2Envelop721.InitParams(
            address(1), // user address
            'Envelop User',
            'ENV',
            'https://api.envelop.is/',
            addrs2,
            new bytes32[](0),
            np,
            ""
        );
        //vm.prank(address(this));
        _wnftWallet2 = payable(impl_myshch.createWNFTonFactory(initData));

    }
    
    function test_transfer_with_refund() public {

        

        
        WNFTMyshchWallet wnftBot = WNFTMyshchWallet(_wnftWallet1);
        WNFTMyshchWallet wnftUser = WNFTMyshchWallet(_wnftWallet2);
        
        // this balance
        balances.push(Bal(
            address(this).balance, 0 // before after
        ));
        
        // bot balance 
        balances.push(Bal(
           _wnftWallet1.balance, 0 // before after
        ));
        // send erc20 to wnft wallet
        erc20.transfer(address(wnftBot), sendERC20Amount);
        
        //WNFTMyshchWallet wnft2 = WNFTMyshchWallet(_wnftWallet2);

        //wnft1.setApprovalForAll(address(2), true);

        //send eth to user wnft wallet
        vm.deal(_wnftWallet2, sendEtherAmount);
        //_wnftWallet2.transfer(sendEtherAmount);
        //console2.log(address(2).balance);
        
        // user balance
        balances.push(Bal(
            _wnftWallet2.balance, 0 // before after
        ));

        // user balance
        balances.push(Bal(
            msg.sender.balance, 0 // before after
        ));
        console2.log("UserWallet: %s, value:%s", _wnftWallet2, balances[2].before);
        //console2.log(_wnftWallet2.balance);
        //vm.prank(address(2));
        uint256 gas_price = 1;
        vm.txGasPrice(gas_price);
        wnftBot.erc20TransferWithRefund(address(erc20), address(wnftUser), sendERC20Amount);
        VmSafe.Gas memory gasInfo = vm.lastCallGas();
        console2.log("Gas used: %s", gasInfo.gasTotalUsed);
        balances[0].afterb =  address(this).balance;
        balances[1].afterb =  _wnftWallet1.balance;
        balances[2].afterb =  _wnftWallet2.balance;
        balances[3].afterb =  msg.sender.balance;
        //console2.log(address(2).balance);
        
        for (uint256 i = 0; i < balances.length; ++ i) {
            console2.log("Index: %s, before: %s", i, balances[i].before);
            console2.log("Index: %s, after : %s", i, balances[i].afterb);
        }
        // console2.log(_wnftWallet2.balance);
        // console2.log(balances[3].afterb);
        // console2.log(balances[3].afterb);
        assertGt(balances[0].afterb - balances[0].before, gasInfo.gasTotalUsed * gas_price);
        assertGt(balances[2].before - balances[2].afterb, gasInfo.gasTotalUsed * gas_price);
    }

    // function test_check_setGasCheckPoint() public {
        
    //     WNFTMyshchWallet wnft1 = WNFTMyshchWallet(_wnftWallet1);

    //     vm.expectRevert("Only for approved relayer");
    //     wnft1.setGasCheckPoint();

    //     wnft1.setRelayerStatus(address(this), true);
    //     wnft1.setGasCheckPoint();
    //     assertGt(wnft1.gasLeftOnStart(),0);

    //     vm.prank(address(1));
    //     vm.expectRevert('Only for wNFT owner');
    //     wnft1.setRelayerStatus(address(1), true);
    // }

    // function test_check_getRefund() public {
        
    //     WNFTMyshchWallet wnft1 = WNFTMyshchWallet(_wnftWallet1);

    //     vm.expectRevert("Only for approved relayer");
    //     wnft1.getRefund();

    //     wnft1.setRelayerStatus(address(1), true);
    //     assertEq(wnft1.getRelayerStatus(address(1)), true);
    //     vm.prank(address(1));
    //     wnft1.setGasCheckPoint();
    //     assertGt(wnft1.gasLeftOnStart(),0);

    //     vm.prank(address(1));
    //     vm.txGasPrice(2);
    //     vm.expectRevert();
    //     wnft1.getRefund();

    //     _wnftWallet1.transfer(sendEtherAmount);

    //     console2.log(address(1).balance);
    //     vm.txGasPrice(2);
    //     vm.prank(address(1));
    //     wnft1.getRefund();
    //     console2.log(address(1).balance);
    // }
}