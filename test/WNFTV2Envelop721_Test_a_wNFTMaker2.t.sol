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
contract WNFTV2Envelop721_Test_a_wNFTMaker2 is Test {
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
        erc721 = new MockERC721("Mock ERC721", "ERC");
        factory = new EnvelopWNFTFactory();
        impl_native = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(impl_native), true); // set wrapper
        erc20_1 = new MockERC20("Mock ERC20", "ERC20");
        erc20_2 = new MockERC20("Mock ERC20", "ERC20");
        erc1155 = new MockERC1155("https://bunny.com");
    }

    function test_wNFTMaker() public {
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            address(this),
            "Envelop",
            "ENV",
            "https://api.envelop.is/",
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

        // make new wnftWallet using executeOp
        // transfer erc20 tyokens to new wnftWallet
        // make 2 child wallets
        // transfer erc20 tokens from master wallet to child wallets

        address[] memory targets = new address[](4);
        bytes[] memory dataArray = new bytes[](4);
        uint256[] memory values = new uint256[](4);

        /*targets[0] = address(impl_native);
        targets[1] = address(impl_native);*/
        targets[0] = address(1);
        targets[1] = address(2);
        targets[2] = address(erc20_1);
        targets[3] = address(erc20_1);

        // prepare data for deploying of child wallets
        initData = WNFTV2Envelop721.InitParams(
            address(1),
            "Envelop",
            "ENV",
            "https://api.envelop.is/",
            new address[](0),
            new bytes32[](0),
            new uint256[](0),
            ""
        );

        // using method with salt
        /*bytes memory _data = abi.encodeWithSignature(
            "createWNFTonFactory2((address,string,string,string,address[],bytes32[],uint256[],bytes))",
            initData
        );*/
        bytes memory _data = "";

        values[0] = sendEtherAmount / 2;
        values[1] = sendEtherAmount / 2;
        values[2] = 0;
        values[3] = 0;

        dataArray[0] = _data;
        dataArray[1] = _data;
        dataArray[2] = abi.encodeWithSignature("transfer(address,uint256)", address(1), sendERC20Amount / 2);
        dataArray[3] = abi.encodeWithSignature("transfer(address,uint256)", address(2), sendERC20Amount / 2);

        (bool sent, bytes memory data) = _wnftWallet.call{value: sendEtherAmount}("");
        console2.log(_wnftWallet.balance);

        // from 599 address
        bytes[] memory result = wnft.executeEncodedTxBatch(targets, values, dataArray);
        console2.log(address(1).balance);
        console2.log(address(2).balance);
        console2.log(erc20_1.balanceOf(address(1)));
        console2.log(erc20_1.balanceOf(address(2)));
    }
}
