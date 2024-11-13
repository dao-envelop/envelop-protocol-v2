// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {MyShchFactory} from "../src/MyShchFactory.sol";
import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import "../src/impl/WNFTV2Envelop721.sol";
import "../src/interfaces/IEnvelopV2wNFT.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// create wnft wallet for user

contract MyShchFactory_Test_a_01 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    uint64 BOT_TG_ID = 111111;
    uint64 USER_TG_ID = 222222;
    MockERC721 public erc721;
    MockERC20 public erc20;
    MyShchFactory public factory;
    WNFTMyshchWallet public impl_myshch;

    //address payable _wnftWallet1;
    //address payable _wnftWallet2;
    address payable botWNFT;
    address payable userWNFT;

    receive() external payable virtual {}
    
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        impl_myshch = new WNFTMyshchWallet(address(0), 0);
        factory = new MyShchFactory(address(impl_myshch));
        factory.setSignerStatus(address(1), true); // address(1) is trusted address
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
    }

    // create wallet by trusted signer
    
    function test_create_wnft() public {
        vm.startPrank(address(1));
        // create wnft for bot tg id
        vm.expectEmit();
        emit EnvelopWNFTFactory.EnvelopV2Deployment(
            factory.getAddressForNonce(BOT_TG_ID, 1), 
            address(impl_myshch),
            impl_myshch.ORACLE_TYPE()
        );
        botWNFT = payable(factory.mintPersonalMSW(BOT_TG_ID, ""));
        vm.stopPrank();

        // create wnft for user tg id
        vm.prank(address(1));
        userWNFT = payable(factory.mintPersonalMSW(USER_TG_ID, ""));

        assertEq(factory.getCurrentAddress(BOT_TG_ID), botWNFT);
        assertEq(factory.getCurrentAddress(BOT_TG_ID), factory.getAddressForNonce(BOT_TG_ID, 1));
        (bool isTrusted, uint64 tg_id) = factory.trustedSigners(address(1));
        assertEq(tg_id, BOT_TG_ID);

        // try to call non-trusted signer - without right signature
        vm.expectRevert(
            abi.encodeWithSelector(MyShchFactory.UnexpectedSigner.selector, address(0))
        );
        botWNFT = payable(factory.mintPersonalMSW(BOT_TG_ID, ""));
    }

    // create wallet using signature
    /*function test_create_wnft() public {
        vm.startPrank(address(1));
        // create wnft for bot tg id
        vm.expectEmit();
        emit EnvelopWNFTFactory.EnvelopV2Deployment(
            factory.getAddressForNonce(BOT_TG_ID, 1), 
            address(impl_myshch),
            impl_myshch.ORACLE_TYPE()
        );
        botWNFT = payable(factory.mintPersonalMSW(BOT_TG_ID, ""));
        vm.stopPrank();

        // create wnft for user tg id
        //vm.prank(address(1));
        //userWNFT = payable(factory.mintPersonalMSW(USER_TG_ID, ""));

        assertEq(factory.getCurrentAddress(BOT_TG_ID), botWNFT);
        assertEq(factory.getCurrentAddress(BOT_TG_ID), factory.getAddressForNonce(BOT_TG_ID, 1));
        (bool isTrusted, uint64 tg_id) = factory.trustedSigners(address(1));
        assertEq(tg_id, BOT_TG_ID);
    }*/

}