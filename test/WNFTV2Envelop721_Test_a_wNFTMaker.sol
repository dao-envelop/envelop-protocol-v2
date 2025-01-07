// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {MockERC1155} from "../src/mock/MockERC1155.sol";
import "../src/impl/WNFTV2Envelop721.sol";
import "../src/EnvelopLegacyWrapperBaseV2.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// add collateral to wnft (erc721, erc1155) and withdraw
contract WNFTV2Envelop721_Test_a_wNFTMaker is Test  {
    using Strings for uint160;
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    uint256 timelock = 10000;
    MockERC721 public erc721;
    MockERC20 public erc20_1;
    MockERC20 public erc20_2;
    MockERC1155 public erc1155;
    EnvelopWNFTFactory public factory;
    WNFTV2Envelop721 public impl_legacy;
    EnvelopLegacyWrapperBaseV2 public wrapper;


    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(impl_legacy), true); // set wrapper
        erc20_1 = new MockERC20('Mock ERC20', 'ERC20');
        erc20_2 = new MockERC20('Mock ERC20', 'ERC20');
        erc1155 = new MockERC1155('https://bunny.com');
    }

    function test_wNFTMaker() public {
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

        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWallet);
        erc20_1.transfer(_wnftWallet, sendEtherAmount);
        erc20_2.transfer(_wnftWallet, 2 * sendEtherAmount);

        // make new wnftWallet using executeOp
        // transfer erc20 tyokens to new wnftWallet
        // make 2 child wallets
        // transfer erc20 tokens from master wallet to child wallets

        address[] memory targets = new address[](6);
        bytes[] memory dataArray = new bytes[](6);
        uint256[] memory values = new uint256[](6);

        targets[0] = address(impl_legacy);
        targets[1] = address(impl_legacy);
        targets[2] = address(erc20_1);
        targets[3] = address(erc20_1);
        targets[4] = address(erc20_2);
        targets[5] = address(erc20_2);

        // prepare data for deploying of child wallets
        initData = WNFTV2Envelop721.InitParams(
            address(1),
            'Envelop',
            'ENV',
            'https://api.envelop.is/',
            new address[](0),
            new bytes32[](0),
            new uint256[](0),
            ""
            );

        // using method with salt
        bytes memory _data = abi.encodeWithSignature(
            "createWNFTonFactory2((address,string,string,string,address[],bytes32[],uint256[],bytes))",
            initData
        );

        for (uint i =0; i < 6; i++)
        {
            values[i] = 0;    
        }
        
        // calc child wallet addresses
        bytes32 salt = keccak256(abi.encode(address(impl_legacy), impl_legacy.nonce() + 1));
        address calcW1 = factory.predictDeterministicAddress(address(impl_legacy), salt);
        salt = keccak256(abi.encode(address(impl_legacy), impl_legacy.nonce() + 2));
        address calcW2 = factory.predictDeterministicAddress(address(impl_legacy), salt);

        dataArray[0] = _data;
        dataArray[1] = _data;
        dataArray[2] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            calcW1,sendEtherAmount / 2
        );
        dataArray[3] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            calcW2,sendEtherAmount / 2
        );
        dataArray[4] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            calcW1,sendEtherAmount
        );
        dataArray[5] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            calcW2,sendEtherAmount
        );

        bytes[] memory result = wnft.executeEncodedTxBatch(targets, values, dataArray);

        // get child wallet adresses from output
        address payable w1 =  payable(abi.decode(result[0],
             (address)
        ));

        address payable w2 =  payable(abi.decode(result[1],
             (address)
        ));

        // check balance of child wallets
        assertEq(erc20_1.balanceOf(w1), sendEtherAmount / 2);
        assertEq(erc20_1.balanceOf(w2), sendEtherAmount / 2);
        assertEq(erc20_2.balanceOf(w1), sendEtherAmount);
        assertEq(erc20_2.balanceOf(w2), sendEtherAmount);

        bytes memory dd = abi.encodeWithSignature(
            "transfer(address,uint256)",
            0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E,10000000000000000000);
        console2.logBytes(dd);
    }

    
}