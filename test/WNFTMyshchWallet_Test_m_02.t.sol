// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {MyShchFactory} from "../src/MyShchFactory.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import "../src/impl/WNFTV2Envelop721.sol";
import "../src/impl/CustomERC20.sol";

//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// call erc20TransferWithRefund
// owner of admin wnft wallet call function
// user wnft wallet gets erc20 tokens and send eth for tx

contract WNFTMyshchWallet_Test_m_02 is Test {
    
    event Log(string message);
    
    struct Bal {
        uint256 before;
        uint256 afterb;
    }
    struct LocalParams {
        uint256 sendEtherAmount;
        uint256 sendERC20Amount;
        address payable botWallet;
        address payable customWallet;
        address customERC20;
        uint64 botId;
        uint64 userTgId;
    }

    address public constant botEOA   = 0x4b664eD07D19d0b192A037Cfb331644cA536029d;
    uint256 public constant botEOA_PRIVKEY = 0x3480b19b170c5e63c0bdb18d08c4a99628194c7dceaf79e0e17431f4a5c7b1f2;
    
    address public constant userEOA =  0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC;
    uint256 public constant userEOA_PRIVKEY = 0xae8fe3985898986377b19cc6bdbb76723470552e95e4d028d2dae2691ab9c65d;
    
    MyShchFactory public myshch_factory;
    WNFTMyshchWallet public impl_myshch;
    CustomERC20 public impl_erc20;

    LocalParams lp;
    Bal[] balances;

    
    function setUp() public {
        impl_myshch = new WNFTMyshchWallet(address(0));
        myshch_factory = new MyShchFactory(address(impl_myshch));
        impl_erc20 = new CustomERC20();

        lp.botId = uint64(0);
        lp.userTgId = uint64(22222);
        lp.sendEtherAmount = 1e18;
        lp.sendERC20Amount = 3e18;

       
        // Topup user EOA
        payable(userEOA).transfer(lp.sendEtherAmount);
        payable(botEOA).transfer(lp.sendEtherAmount);

        // Add trusted signers
        //myshch_factory.setSignerStatus(address(this), true);
        myshch_factory.setSignerStatus(botEOA, true);
        myshch_factory.newImplementation(
            MyShchFactory.AssetType.ERC20, 
            address(impl_erc20)
        );
        
        // create admin wnft wallet
        vm.prank(botEOA);
        lp.botWallet = payable(myshch_factory.mintPersonalMSW(0, "")); 
        
        // prepare signature fro user wnft wallet
        bytes memory botSignature;
        bytes32 digest =  MessageHashUtils.toEthSignedMessageHash(
            myshch_factory.getDigestForSign(lp.userTgId, myshch_factory.currentNonce(lp.userTgId) + 1)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(botEOA_PRIVKEY, digest);
        botSignature = abi.encodePacked(r,s,v); 

        // create user wnft wallet
        vm.prank(userEOA);
        lp.customWallet = payable(myshch_factory.mintPersonalMSW{value: lp.sendEtherAmount}(lp.userTgId, botSignature)); 

        // Create erc20 for distribution
        MyShchFactory.InitDistributtion[] memory initDisrtrib = new MyShchFactory.InitDistributtion[](2);
        initDisrtrib[0] = MyShchFactory.InitDistributtion(lp.botWallet, 10e18);
        initDisrtrib[1] = MyShchFactory.InitDistributtion(address(2), 200);
        lp.customERC20 = myshch_factory.createCustomERC20(
            address(this),           // _creator,
            "Custom ERC20 Name",     // name_,
            "CUSTSYM",               // symbol_,
            1_000_000e18,            // _totalSupply,
            initDisrtrib             // _initialHolders
        );
        console2.log("Custom ERC20 token created: %s", address(lp.customERC20));
    }
    
    function test_transfer_with_refund() public {
        WNFTMyshchWallet wnftBot  = WNFTMyshchWallet(lp.botWallet);
        WNFTMyshchWallet wnftUser = WNFTMyshchWallet(lp.customWallet);
        CustomERC20 erc20 = CustomERC20(lp.customERC20);
        // this balance
        balances.push(Bal(
            address(this).balance, 0 // before after
        ));
        
        // bot balance 
        balances.push(Bal(
           lp.botWallet.balance, 0 // before after
        ));

        // customer balance 
        balances.push(Bal(
           lp.customWallet.balance, 0 // before after
        ));

        // gasSPender
        // customer balance 
        balances.push(Bal(
           botEOA.balance, 0 // before after
        ));

            
        console2.log("UserWallet: %s, value:%s", lp.customWallet, balances[2].before);
        uint256 gas_price = 1e9;
        vm.txGasPrice(gas_price);
        vm.prank(botEOA);
        wnftBot.erc20TransferWithRefund(address(erc20), address(wnftUser), lp.sendERC20Amount);
        VmSafe.Gas memory gasInfo = vm.lastCallGas();
        console2.log("Gas used: %s", gasInfo.gasTotalUsed);
        balances[0].afterb =  address(this).balance;
        balances[1].afterb =  lp.botWallet.balance;
        balances[2].afterb =  lp.customWallet.balance;
        balances[3].afterb =  botEOA.balance;
        //console2.log(address(2).balance);
        
        for (uint256 i = 0; i < balances.length; ++ i) {
            console2.log("Index: %s, before: %s", i, balances[i].before);
            console2.log("Index: %s, after : %s", i, balances[i].afterb);
        }
        assertGt(balances[2].before - balances[2].afterb, gasInfo.gasTotalUsed * gas_price);
    }
}