// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {MyShchFactory} from "../src/MyShchFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTMyshchWallet.sol";
//import "../src/impl/WNFTV2Envelop721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// call erc20TransferWithRefund
// owner of admin wnft wallet call function
// user wnft wallet gets erc20 tokens and send eth for tx

// Address:     0x7EC0BF0a4D535Ea220c6bD961e352B752906D568
// Private key: 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71
// Signature:   
//              

// Address:     0x4b664eD07D19d0b192A037Cfb331644cA536029d
// Private key: 0x3480b19b170c5e63c0bdb18d08c4a99628194c7dceaf79e0e17431f4a5c7b1f2
// Signature:   
//              


// Address:     0xd7DE4B1214bFfd5C3E9Fb8A501D1a7bF18569882
// Private key: 0x8ba574046f1e9e372e805aa6c5dcf5598830df5a78605b7713bf00f2f3329148
// Signature: 
//            


contract MyShchFactory_Test_m_01 is Test {
    address public constant botEOA   = 0x7EC0BF0a4D535Ea220c6bD961e352B752906D568;
    uint256 public constant botEOA_PRIVKEY = 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71;
    address public constant adminEOA = 0x4b664eD07D19d0b192A037Cfb331644cA536029d;
    address public constant userEOA  = 0xd7DE4B1214bFfd5C3E9Fb8A501D1a7bF18569882;
    uint64  public constant BOT_TG_ID = 111111111;
    uint64  public constant USER_TG_ID = 222222222;
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    MockERC721 public erc721;
    MockERC20 public erc20;
    MyShchFactory public factory;
    WNFTMyshchWallet public impl_myshch;

    address payable botWNFT;
    address payable userWNFT;

    receive() external payable virtual {}
    
    function setUp() public {
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        impl_myshch = new WNFTMyshchWallet(address(0), 0);
        factory = new MyShchFactory(address(impl_myshch));
        factory.setSignerStatus(botEOA, true); 
        erc20 = new MockERC20('Mock ERC20', 'ERC20');

        vm.prank(address(botEOA));
        botWNFT = payable(factory.mintPersonalMSW(BOT_TG_ID, ""));

    }
    
    function test_wnft_bot_wallet() public {
        assertNotEq(botWNFT, address(impl_myshch));
        
    }

    function test_wnft_user_wallet() public {
        vm.deal(userEOA, sendEtherAmount);
        bytes memory botSignature;
        bytes32 digest = factory.getDigestForSign(USER_TG_ID, factory.currentNonce(USER_TG_ID) + 1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(botEOA_PRIVKEY, digest);
        botSignature = abi.encodePacked(r,s,v);
        vm.prank(userEOA);
        userWNFT = payable(factory.mintPersonalMSW{value: sendEtherAmount}(USER_TG_ID, botSignature));
        assertNotEq(userWNFT, address(impl_myshch));
        assertEq(userEOA.balance, 0);
        assertEq(userWNFT.balance, sendEtherAmount);
    }
}