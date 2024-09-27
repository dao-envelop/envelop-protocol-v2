// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTLegacy721.sol";
import "../src/impl/WNFTV2Envelop721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";


contract Factory_Test_m_03 is Test {
    address public constant addr4 = 0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC;
    uint256 public sendEtherAmount = 1e18;
    EnvelopWNFTFactory public factory;
    WNFTMyshchWallet public impl_myshch;
    WNFTMyshchWallet public walletServ;
    WNFTMyshchWallet public walletUser;
    WNFTV2Envelop721 public impl_native;
    MockERC20 public erc20;
    uint256 public nonce;
    uint256 public sendERC20Amount = 1e14;

    receive() external payable virtual {}
    function setUp() public {
        erc20 = new MockERC20("Name of Mock", "MMM");
        factory = new EnvelopWNFTFactory();
        impl_myshch = new WNFTMyshchWallet(address(factory));
        impl_native = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(this), true); // set wrapper
        factory.setWrapperStatus(address(impl_myshch), true); // set wrapper
        factory.setWrapperStatus(address(impl_native), true); // set wrapper

        // struct InitParams {
        //     address creator;
        //     string nftName;
        //     string nftSymbol;
        //     string tokenUri;
        //     address[] addrParams;    // Semantic of this param will defined in exact implemenation 
        //     bytes32[] hashedParams;  // Semantic of this param will defined in exact implemenation
        //     uint256[] numberParams;  // Semantic of this param will defined in exact implemenation
        //     bytes bytesParam;        // Semantic of this param will defined in exact implemenation
        // }
        bytes memory initCallData = abi.encodeWithSignature(
            impl_native.INITIAL_SIGN_STR(),
            WNFTV2Envelop721.InitParams(
                address(this), 
                "MyshchWallet", 
                "MSHW", 
                "https://api.envelop.is",
                new address[](0),
                new bytes32[](0),
                new uint256[](0),
                "" 
            )
        );
        address payable  created = payable(factory.createWNFT(address(impl_native), initCallData));
        
        // prepare
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
