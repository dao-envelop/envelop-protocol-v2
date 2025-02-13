// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import "../src/impl/WNFTV2Envelop721.sol";
import "../src/impl/SmartWallet.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";


contract WNFTV2Envelop721_Test_a_01 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    MockERC721 public erc721;
    EnvelopWNFTFactory public factory;
    WNFTV2Envelop721 public impl_legacy;

    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(impl_legacy), true); // set wrapper
        
    }
    
    // spender of wnft wallet withdraws eth from wallet
    function test_create_wNFT() public {
        bytes2 rule = 0x0000;
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            address(1),
            'Envelop',
            'ENV',
            'https://api.envelop.is/',
            new address[](0),
            new bytes32[](0),
            new uint256[](0),
            ""
            );

        vm.prank(address(1));
        address payable _wnftWallet = payable(impl_legacy.createWNFTonFactory(initData));

        assertNotEq(_wnftWallet, address(impl_legacy));
        
        // send eth to wnft wallet
        vm.prank(address(this));
        vm.expectEmit();
        emit SmartWallet.EtherReceived(sendEtherAmount, sendEtherAmount, address(this));
        (bool sent, bytes memory data) = _wnftWallet.call{value: sendEtherAmount}("");
        // suppress solc warnings 
        sent;
        data;
        assertEq(address(_wnftWallet).balance, sendEtherAmount);
        
        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWallet);
        assertEq(wnft.wnftInfo(impl_legacy.TOKEN_ID()).rules, rule);
        
        vm.prank(address(1));
        wnft.setApprovalForAll(address(2), true);

        vm.prank(address(2));
        // try to withdraw eth from collateral
        data = "";
        vm.expectEmit();
        emit SmartWallet.EtherBalanceChanged(sendEtherAmount, sendEtherAmount / 2, 0, address(2));
        wnft.executeEncodedTx(address(2), sendEtherAmount / 2, data); 
        assertEq(address(2).balance, sendEtherAmount / 2);
        assertEq(_wnftWallet.balance, sendEtherAmount / 2);

    }

    // unsupported rules
    function test_checkRules() public {
        bytes32 rule = bytes32(abi.encode(7));
        bytes32 calcRule = bytes32(abi.encode(3));
        console2.logBytes(bytes.concat(rule));
        console2.logBytes2(bytes2(calcRule));
        console2.logBytes32(bytes32(abi.encode(7)));
        console2.logBytes32(bytes32(abi.encode(3)));
        console2.logBytes2(impl_legacy.SUPPORTED_RULES());
        bytes32[] memory hashedParams = new bytes32[](1);
        hashedParams[0] = rule;
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            address(1),
            'Envelop',
            'ENV',
            'https://api.envelop.is/',
            new address[](0),
            hashedParams,
            new uint256[](0),
            ""
            );
                
        /// Bellow is commented because in base WNFTV2Envelop721 inmplementation
        /// we enable user to set any rule. But only No_Transfer rule  checked in this 
        /// implementation.
        /// It is possible to overide `_isValidRules(bytes2 _rules)` in inheritors to
        /// implement custom logic

        // vm.expectRevert(
        //     abi.encodeWithSelector(WNFTV2Envelop721.RuleSetNotSupported.selector, calcRule)
        // );
        address payable _wnftWallet = payable(impl_legacy.createWNFTonFactory(initData));
    }
}