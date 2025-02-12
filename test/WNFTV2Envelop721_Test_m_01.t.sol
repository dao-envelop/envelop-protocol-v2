// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import  "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTV2Envelop721.sol";
import {ReentrancyAttacker3} from "../src/mock/ReentrancyAttacker3.sol";

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


contract WNFTV2Envelop721_Test_m_01 is Test {
    address public constant botEOA   = 0x7EC0BF0a4D535Ea220c6bD961e352B752906D568;
    uint256 public constant botEOA_PRIVKEY = 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71;
    address public constant adminEOA = 0x4b664eD07D19d0b192A037Cfb331644cA536029d;
    address public constant userEOA  = 0xd7DE4B1214bFfd5C3E9Fb8A501D1a7bF18569882;
    

    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    MockERC721 public erc721;
    MockERC20 public erc20;
    EnvelopWNFTFactory public factory;
    WNFTV2Envelop721 public impl_native;

    address payable botWNFT;
    address payable userWNFT;

    receive() external payable virtual {}
    
    function setUp() public {
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
        impl_native = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(impl_native), true); 

    }
    
    

    function test_execWithSignature() public {
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

        //vm.prank(address(this));
        address payable _wnftWalletAddress = payable(impl_native.createWNFTonFactory(initData));
        
        // topup wnft wallet
        erc20.transfer(_wnftWalletAddress, sendERC20Amount); 
        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWalletAddress);
        wnft.setSignerStatus(botEOA, true); //set trusted signer
        bytes32 pureDigest = wnft.getDigestForSign(
            address(erc20), // target
            0, // ether value
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                userEOA, sendERC20Amount / 2
            ), //data
            userEOA
        );
        // conevert pure digest to RETH style
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(pureDigest);

        vm.deal(userEOA, sendEtherAmount);
        bytes memory botSignature;
        
        // sign
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(botEOA_PRIVKEY, digest);
        botSignature = abi.encodePacked(r,s,v);
        
        assertEq(erc20.balanceOf(userEOA), 0);
        assertEq(wnft.getCurrentNonceForAddress(userEOA), 0);
        
        vm.startPrank(userEOA);
        // Execute from other adress with signature
        wnft.executeEncodedTxBySignature(
            address(erc20), // target
            0, // ether value
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                userEOA, sendERC20Amount / 2
            ), //data
            botSignature
        );
        assertEq(erc20.balanceOf(userEOA), sendERC20Amount / 2);
        assertEq(wnft.getCurrentNonceForAddress(userEOA), 1);
    }


    function test_execWithSignature_Reentrancy() public {
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

        //vm.prank(address(this));
        address payable _wnftWalletAddress = payable(impl_native.createWNFTonFactory(initData));
        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWalletAddress);
        wnft.setSignerStatus(botEOA, true); //set trusted signer

        (bool sent, bytes memory data) = _wnftWalletAddress.call{value: sendEtherAmount * 10}("");

        bytes memory _data = "";
        ReentrancyAttacker3 hacker = new ReentrancyAttacker3(_wnftWalletAddress);

        // prepare signature
        bytes32 pureDigest = wnft.getDigestForSign(
            address(hacker), // target
            sendEtherAmount, // ether value
            "", //data
            address(hacker)
        );
        // convert pure digest to RETH style
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(pureDigest);

        bytes memory signature;
        
        // sign
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(botEOA_PRIVKEY, digest);
        signature = abi.encodePacked(r,s,v);

        hacker.setSignature(signature);

        vm.startPrank(userEOA);

        assertEq(0, address(hacker).balance);

        vm.expectPartialRevert(WNFTV2Envelop721.UnexpectedSigner.selector);
        //vm.expectRevert();
        hacker.claimEther(sendEtherAmount);
        
        assertEq(0, address(hacker).balance);
        //console2.log(erc20.balanceOf(address(2)));
        //vm.startPrank(userEOA);
        //wnft.executeEncodedTxBySignature(address(hacker), sendEtherAmount, _data, signature);
        //console2.log(address(hacker).balance);
    }
}