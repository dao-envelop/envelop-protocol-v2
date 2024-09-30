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

// make approveHiden by owner and non-owner
contract WNFTV2Envelop721_Test_a_06 is Test {
    
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

        vm.prank(address(this));
        address payable _wnftWallet = payable(impl_legacy.createWNFTonFactory(initData));

        // send erc20 to wnft wallet
        erc20.transfer(_wnftWallet, sendERC20Amount);
        
        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWallet);

        // send erc20 to wnft wallet
        erc20.transfer(_wnftWallet, sendERC20Amount);
        
        console2.log("Owner of wnft: %s", wnft.ownerOf(wnft.TOKEN_ID()));
                
        uint256 tokenId = impl_legacy.TOKEN_ID();
        vm.prank(address(2)); // by non-owner
        vm.expectRevert(
            abi.encodeWithSelector(ERC721InvalidApprover.selector, address(2))
        );
        wnft.approveHiden(address(10), tokenId);
        
        wnft.approveHiden(address(1), tokenId);
        assertEq(wnft.getApproved(tokenId), address(1));

        // transfer and check approve
        wnft.transferFrom(address(this), address(2), tokenId);
        assertEq(wnft.getApproved(tokenId), address(0));
    }
}