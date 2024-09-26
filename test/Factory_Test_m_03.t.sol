// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {WNFTMyshchWallet} from "../src/impl/WNFTMyshchWallet.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTLegacy721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";


contract Factory_Test_m_02 is Test {
    address public constant addr4 = 0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC;
    uint256 public sendEtherAmount = 1e18;
    EnvelopWNFTFactory public factory;
    WNFTMyshchWallet public impl_myshch;
    WNFTMyshchWallet public walletServ;
    WNFTMyshchWallet public walletUser;
    MockERC20 public erc20;
    uint256 public nonce;
    uint256 public sendERC20Amount = 1e14;

    receive() external payable virtual {}
    function setUp() public {
        erc20 = new MockERC20("Name of Mock", "MMM");
        factory = new EnvelopWNFTFactory();
        impl_myshch = new WNFTMyshchWallet();
        factory.setWrapperStatus(address(this), true); // set wrapper
        bytes memory initCallData = abi.encodeWithSignature(
            impl_myshch.INITIAL_SIGN_STR(),
            address(this), "MyshchWallet", "MSHW", "https://api.envelop.is" 
        );
        address payable  created = payable(factory.createWNFT(address(impl_myshch), initCallData));
        walletServ = WNFTMyshchWallet(created);
        created = payable(factory.createWNFT(address(impl_myshch), initCallData));
        walletUser = WNFTMyshchWallet(created);
        Address.sendValue(payable(walletServ), 1e18);
        Address.sendValue(payable(walletUser), 2e18);
        erc20.transfer(address(walletServ), 100e18);
        assertNotEq(address(walletUser), address(walletServ));
        assertNotEq(erc20.balanceOf(address(walletUser)), erc20.balanceOf(address(walletServ)));

    }

    function test_create_exec_with_refund() public {

        bytes memory _data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(walletUser), sendERC20Amount
        );

        // by owner
        walletServ.erc20TransferWithRefund(address(erc20), address(walletUser), sendERC20Amount);
        
        assertNotEq(address(walletUser), address(walletServ));
        assertEq(erc20.balanceOf(address(walletUser)), sendERC20Amount);

    }

    
}
