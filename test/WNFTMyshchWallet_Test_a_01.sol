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

    address payable _wnftWallet1;
    address payable _wnftWallet2;

    receive() external payable virtual {}
    
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
        impl_myshch = new WNFTMyshchWallet(address(factory), 0);
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
        _wnftWallet1 = payable(impl_myshch.createWNFTonFactory(initData));

        // create user wnft wallet
        address[] memory addrs2 = new address[](1);
        addrs2[0] = _wnftWallet1;  // add relayer
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
        _wnftWallet2 = payable(impl_myshch.createWNFTonFactory(initData));

    }
    
    function test_create_wnft() public {
        
        WNFTMyshchWallet wnft1 = WNFTMyshchWallet(_wnftWallet1);

        // send erc20 to wnft wallet
        erc20.transfer(_wnftWallet1, sendERC20Amount);
        
        //WNFTMyshchWallet wnft2 = WNFTMyshchWallet(_wnftWallet2);

        wnft1.setApprovalForAll(address(2), true);

        //send eth to user wnft wallet
        _wnftWallet2.transfer(sendEtherAmount);
        console2.log(address(2).balance);
        console2.log(_wnftWallet2.balance);
        vm.prank(address(2));
        vm.txGasPrice(2);
        wnft1.erc20TransferWithRefund(address(erc20), _wnftWallet2, sendERC20Amount);
        VmSafe.Gas memory gasInfo = vm.lastCallGas();
        console2.log(gasInfo.gasTotalUsed);
        console2.log(address(2).balance);
        console2.log(_wnftWallet2.balance);
    }

    function test_check_setGasCheckPoint() public {
        
        WNFTMyshchWallet wnft1 = WNFTMyshchWallet(_wnftWallet1);

        vm.expectRevert("Only for approved relayer");
        wnft1.setGasCheckPoint();

        wnft1.setRelayerStatus(address(this), true);
        wnft1.setGasCheckPoint();
        assertGt(wnft1.gasLeftOnStart(),0);

        vm.prank(address(1));
        vm.expectRevert('Only for wNFT owner');
        wnft1.setRelayerStatus(address(1), true);
    }

    function test_check_getRefund() public {
        
        WNFTMyshchWallet wnft1 = WNFTMyshchWallet(_wnftWallet1);

        vm.expectRevert("Only for approved relayer");
        wnft1.getRefund();

        wnft1.setRelayerStatus(address(1), true);
        assertEq(wnft1.getRelayerStatus(address(1)), true);
        vm.prank(address(1));
        wnft1.setGasCheckPoint();
        assertGt(wnft1.gasLeftOnStart(),0);

        vm.prank(address(1));
        vm.txGasPrice(2);
        vm.expectRevert();
        wnft1.getRefund();

        _wnftWallet1.transfer(sendEtherAmount);

        console2.log(address(1).balance);
        vm.txGasPrice(2);
        vm.prank(address(1));
        wnft1.getRefund();
        console2.log(address(1).balance);
    }
}