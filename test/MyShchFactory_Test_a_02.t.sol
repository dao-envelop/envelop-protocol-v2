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

contract MyShchFactory_Test_a_02 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    uint64 BOT_TG_ID = 111111;
    uint64 USER_TG_ID = 222222;
    address public constant botEOA   = 0x7EC0BF0a4D535Ea220c6bD961e352B752906D568;
    uint256 public constant botEOA_PRIVKEY = 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71;
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
        impl_myshch = new WNFTMyshchWallet(address(0));
        factory = new MyShchFactory(address(impl_myshch));
        factory.setSignerStatus(address(1), true); // address(1) is trusted address
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
    }

    // create wallet using signature  and ether in balance
    function test_wnft_user_wallet() public {
        factory.setSignerStatus(botEOA, true); 
        vm.startPrank(botEOA);
        botWNFT = payable(factory.mintPersonalMSW(BOT_TG_ID, ""));
        vm.stopPrank();
        bytes memory botSignature;
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(
            factory.getDigestForSign(USER_TG_ID, factory.currentNonce(USER_TG_ID) + 1));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(botEOA_PRIVKEY, digest);
        botSignature = abi.encodePacked(r,s,v);
        vm.deal(address(2), sendEtherAmount);
        vm.prank(address(2));
        userWNFT = payable(factory.mintPersonalMSW{value: sendEtherAmount}(USER_TG_ID, botSignature));
        assertEq(userWNFT.balance, sendEtherAmount);
        assertEq(WNFTMyshchWallet(userWNFT).getRelayerStatus(botWNFT), true);
        console2.log(WNFTMyshchWallet(userWNFT).tokenURI(1));
    }


    // проверить, кто релеером встает, проверить url
}