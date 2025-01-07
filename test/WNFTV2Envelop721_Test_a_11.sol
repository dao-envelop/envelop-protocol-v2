// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTV2Envelop721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// check no transfer rule 
// check NoDelegateCall error
contract WNFTV2Envelop721_Test_a_11 is Test {
    
    error ERC721InvalidApprover(address approver);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    MockERC721 public erc721;
    MockERC20 public erc20;
    EnvelopWNFTFactory public factory;
    WNFTV2Envelop721 public impl_legacy;

    receive() external payable virtual {}
    
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(impl_legacy), true); // set wrapper
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
    }

    function test_create_wNFT() public {
        bytes32[] memory hashedParams = new bytes32[](1);
        hashedParams[0] = bytes32(abi.encode(4));
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            address(this),
            'Envelop',
            'ENV',
            'https://api.envelop.is/',
            new address[](0),
            hashedParams,
            new uint256[](0),
            ""
            );

        vm.prank(address(this));
        vm.expectEmit();
        emit WNFTV2Envelop721.EnvelopWrappedV2(address(this), impl_legacy.TOKEN_ID(),  bytes2(uint16(uint256(hashedParams[0]))), "");
        address payable _wnftWallet = payable(impl_legacy.createWNFTonFactory(initData));

        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWallet);
        
        uint256 tokenId = impl_legacy.TOKEN_ID();        
        vm.expectRevert(
            abi.encodeWithSelector(WNFTV2Envelop721.WnftRuleViolation.selector, bytes2(0x0004))
        );
        wnft.transferFrom(address(this), address(1), tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(WNFTV2Envelop721.WnftRuleViolation.selector, bytes2(0x0004))
        );
        wnft.safeTransferFrom(address(this), address(1), tokenId, bytes(""));
    }

    function test_notDelegated() public {
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            address(this),
            'Envelop',
            'ENV',
            'https://api.envelop.is/',
            new address[](0),
            new bytes32[](0),
            new uint256[](0),
            ""
            );

        address payable _wnftWallet = payable(impl_legacy.createWNFTonFactory(initData));

        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWallet);

        vm.expectRevert(
            abi.encodeWithSelector(WNFTV2Envelop721.NoDelegateCall.selector)
        );
        wnft.createWNFTonFactory(initData);
    }
}