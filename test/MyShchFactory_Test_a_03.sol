// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import  "../src/MyShchFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {CustomERC20} from "../src/impl/CustomERC20.sol";
import "../src/impl/WNFTMyshchWallet.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// call erc20TransferWithRefund
// owner of admin wnft wallet call function
// user wnft wallet gets erc20 tokens and send eth for tx

contract MyShchFactory_Test_a_03 is Test {
    
    event Log(string message);

    address public constant botEOA   = 0x7EC0BF0a4D535Ea220c6bD961e352B752906D568;
    uint256 public constant botEOA_PRIVKEY = 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71;
    address public constant adminEOA = 0x4b664eD07D19d0b192A037Cfb331644cA536029d;
    address public constant userEOA  = 0xd7DE4B1214bFfd5C3E9Fb8A501D1a7bF18569882;
    uint64  public constant BOT_TG_ID = 111111111;
    uint64  public constant USER_TG_ID = 222222222;

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    MockERC721 public erc721;
    MockERC20 public erc20;
    MyShchFactory public factory;
    WNFTMyshchWallet public impl_myshch;
    CustomERC20 public impl_erc20;

    address payable botWNFT;
    address payable userWNFT;

    receive() external payable virtual {}
    
    function setUp() public {
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        impl_myshch = new WNFTMyshchWallet(address(0));
        factory = new MyShchFactory(address(impl_myshch));
        factory.setSignerStatus(botEOA, true); 
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
        impl_erc20 = new CustomERC20();

    }
    
    function test_custom_erc20() public {
        factory.newImplementation(MyShchFactory.AssetType.ERC20, address(impl_erc20));
        MyShchFactory.InitDistributtion[] memory initDisrtrib = new MyShchFactory.InitDistributtion[](1);
        initDisrtrib[0] = MyShchFactory.InitDistributtion(address(1), 1_000_000e18);
        address custom_20address = factory.createCustomERC20(
            address(this),           // _creator,
            "Custom ERC20 Name",     // name_,
            "CUSTSYM",               // symbol_,
            1_000_000e18,            // _totalSupply,
            initDisrtrib             // _initialHolders
        );
        
        CustomERC20 token = CustomERC20(custom_20address);
        assertEq(
           token.balanceOf(address(1)),
           initDisrtrib[0].amount
        );

        assertEq(
           token.balanceOf(address(this)),
           0
        );
    }
}