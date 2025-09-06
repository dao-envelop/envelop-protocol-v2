// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTLegacy721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// check no transfer rule
contract Factory_Test_a_13 is Test {
    error ERC721InvalidApprover(address approver);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    MockERC721 public erc721;
    MockERC20 public erc20;
    EnvelopWNFTFactory public factory;
    WNFTLegacy721 public impl_legacy;

    receive() external payable virtual {}

    function setUp() public {
        erc721 = new MockERC721("Mock ERC721", "ERC721");
        erc20 = new MockERC20("Mock ERC20", "ERC20");
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTLegacy721();
        factory.setWrapperStatus(address(this), true); // set wrapper
    }

    function test_create_legacy() public {
        bytes memory initCallData = abi.encodeWithSignature(
            impl_legacy.INITIAL_SIGN_STR(),
            address(this), // creator and owner
            "LegacyWNFTNAME",
            "LWNFT",
            "https://api.envelop.is",
            //new ET.WNFT[](1)[0]
            ET.WNFT(
                ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)), 0, 0), // inAsset
                new ET.AssetItem[](0), // collateral
                address(0), //unWrapDestination
                new ET.Fee[](0), // fees
                new ET.Lock[](0), // locks
                new ET.Royalty[](0), // royalties
                0x0004 //bytes2 // no transfer
            )
        );

        address payable _wnftWallet = payable(factory.createWNFT(address(impl_legacy), initCallData));
        assertNotEq(_wnftWallet, address(impl_legacy));

        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);

        uint256 tokenId = impl_legacy.TOKEN_ID();
        vm.expectRevert(abi.encodeWithSelector(WNFTLegacy721.WnftRuleViolation.selector, bytes2(0x0004)));
        wnft.transferFrom(address(this), address(1), tokenId);
    }
}
