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
contract WNFTV2Envelop721_Test_a_10 is Test {
    using Strings for uint160;

    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    uint256 timelock = 10000;
    MockERC721 public erc721;
    MockERC20 public erc20;
    MockERC1155 public erc1155;
    EnvelopWNFTFactory public factory;
    WNFTV2Envelop721 public impl_legacy;
    EnvelopLegacyWrapperBaseV2 public wrapper;

    receive() external payable virtual {}

    function setUp() public {
        erc721 = new MockERC721("Mock ERC721", "ERC");
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(impl_legacy), true); // set wrapper
        erc20 = new MockERC20("Mock ERC20", "ERC20");
        erc1155 = new MockERC1155("https://bunny.com");
    }

    function test_create_wNFT() public {
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
        address payable _wnftWallet = payable(impl_legacy.createWNFTonFactory(initData));

        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWallet);

        uint256 tokenId = 0;
        uint256 amount = 6;
        erc721.transferFrom(address(this), address(wnft), tokenId);
        erc1155.mint(address(wnft), tokenId, amount);

        bytes memory _data =
            abi.encodeWithSignature("transferFrom(address,address,uint256)", address(wnft), address(this), tokenId);

        wnft.executeEncodedTx(address(erc721), 0, _data);
        assertEq(erc721.ownerOf(tokenId), address(this));

        _data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            address(wnft),
            address(1),
            tokenId,
            amount,
            bytes("")
        );

        wnft.executeEncodedTx(address(erc1155), 0, _data);
        assertEq(erc1155.balanceOf(address(1), tokenId), amount);
    }

    function test_wnftInfo() public {
        uint256[] memory numberParams = new uint256[](1);
        numberParams[0] = block.timestamp + 10000;
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            address(this),
            "Envelop",
            "ENV",
            "https://api.envelop.is/",
            new address[](0),
            new bytes32[](0),
            numberParams,
            ""
        );

        vm.prank(address(this));
        address payable _wnftWallet = payable(impl_legacy.createWNFTonFactory(initData));

        WNFTV2Envelop721 wnft = WNFTV2Envelop721(_wnftWallet);

        ET.WNFT memory info = wnft.wnftInfo(impl_legacy.TOKEN_ID());
        assertEq(info.locks[0].param, numberParams[0]);
        assertEq(info.locks[0].lockType, bytes1(""));
    }
}
