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
    WNFTV2Envelop721 public impl_native;
    EnvelopLegacyWrapperBaseV2 public wrapper;


    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
        impl_native = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(impl_native), true); // set wrapper
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
        // create master wallet
        // from 599 address
        address payable _wnftWallet = payable(impl_native.createWNFTonFactory(initData));

        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWallet);
        erc20_1.transfer(_wnftWallet, sendERC20Amount);
        erc20_2.transfer(_wnftWallet, 2 * sendERC20Amount);

        // make new wnftWallet using executeOp
        // transfer erc20 tyokens to new wnftWallet
        // make 2 child wallets
        // transfer erc20 tokens from master wallet to child wallets

        address[] memory targets = new address[](6);
        bytes[] memory dataArray = new bytes[](6);
        uint256[] memory values = new uint256[](6);

        targets[0] = address(impl_native);
        targets[1] = address(impl_native);
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
        bytes32 salt = keccak256(abi.encode(address(impl_native), _wnftWallet, impl_native.nonce(_wnftWallet) + 1));
        address calcW1 = factory.predictDeterministicAddress(address(impl_native), salt);
        salt = keccak256(abi.encode(address(impl_native), _wnftWallet, impl_native.nonce(_wnftWallet) + 2));
        address calcW2 = factory.predictDeterministicAddress(address(impl_native), salt);

        dataArray[0] = _data;
        dataArray[1] = _data;
        dataArray[2] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            calcW1,sendERC20Amount / 2
        );
        dataArray[3] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            calcW2,sendERC20Amount / 2
        );
        dataArray[4] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            calcW1,sendERC20Amount
        );
        dataArray[5] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            calcW2,sendERC20Amount
        );


        // from 599 address
        bytes[] memory result = wnft.executeEncodedTxBatch(targets, values, dataArray);

        // get child wallet adresses from output
        address payable w1 =  payable(abi.decode(result[0],
             (address)
        ));

        address payable w2 =  payable(abi.decode(result[1],
             (address)
        ));

        // check balance of child wallets
        assertEq(erc20_1.balanceOf(w1), sendERC20Amount / 2);
        assertEq(erc20_1.balanceOf(w2), sendERC20Amount / 2);
        assertEq(erc20_2.balanceOf(w1), sendERC20Amount);
        assertEq(erc20_2.balanceOf(w2), sendERC20Amount);
        assertEq(impl_native.nonce(_wnftWallet),2);
    }

    function test_decode() public {
         bytes memory data =   hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000005322E302E32000000000000000000000000000000000000000000000000000000";
        (string memory version, uint256 price) =  (abi.decode(data,
             (string, uint256)
        ));
        console2.log(price);
        console2.log(version);
    } 
}