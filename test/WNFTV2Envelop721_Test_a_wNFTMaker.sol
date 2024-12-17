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
        // transfer erc20 to new wnftWallet
        // сделать несколько кошельков
        // try to executeEncodedTx original nft - revert
        address[] memory targets = new address[](2);
        bytes[] memory dataArray = new bytes[](2);
        uint256[] memory values = new uint256[](2);

        targets[0] = address(impl_legacy);
        targets[1] = address(impl_legacy);

        // prepare data for child wallets
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

        bytes memory _data = abi.encodeWithSignature(
            "createWNFTonFactory((address,string,string,string,address[],bytes32[],uint256[],bytes))",
            initData
        );

        dataArray[0] = _data;
        dataArray[1] = _data;
        values[0] = 0;
        values[1] = 0;

        bytes[] memory result = wnft.executeEncodedTxBatch(targets, values, dataArray);
        //wnft.executeEncodedTx(address(impl_legacy), 0, _data);

        address payable w1 =  payable(abi.decode(result[0],
             (address)
        ));

        console2.log(w1);

        address payable w2 =  payable(abi.decode(result[1],
             (address)
        ));

        WNFTV2Envelop721 childWnft1 = WNFTV2Envelop721(w1);
        WNFTV2Envelop721 childWnft2 = WNFTV2Envelop721(w2);

        // add erc20 tokens to child wnfts
        address[] memory chaildTargets = new address[](4);
        bytes[] memory childDataArray = new bytes[](4);
        uint256[] memory childValues = new uint256[](4);

        chaildTargets[0] = address(erc20_1);
        chaildTargets[1] = address(erc20_1);
        chaildTargets[2] = address(erc20_2);
        chaildTargets[3] = address(erc20_2);

        childDataArray[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            w1,sendEtherAmount / 2
        );
        childDataArray[1] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            w2,sendEtherAmount / 2
        );
        childDataArray[2] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            w1,sendEtherAmount
        );
        childDataArray[3] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            w2,sendEtherAmount
        );

        childValues[0] = 0;
        childValues[1] = 0;
        childValues[2] = 0;
        childValues[3] = 0;

        wnft.executeEncodedTxBatch(chaildTargets, childValues, childDataArray);

        assertEq(erc20_1.balanceOf(w1), sendEtherAmount / 2);
        assertEq(erc20_1.balanceOf(w2), sendEtherAmount / 2);
        assertEq(erc20_2.balanceOf(w1), sendEtherAmount);
        assertEq(erc20_2.balanceOf(w2), sendEtherAmount);


    }
}