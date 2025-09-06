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

// call executeEncodedTx with timelock
contract Factory_Test_a_05 is Test {
    event Log(string message);

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
        ET.Lock[] memory locks = new ET.Lock[](1);
        locks[0] = ET.Lock(0x00, block.timestamp + 10000);
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
                locks, // locks
                new ET.Royalty[](0), // royalties
                0x0105 //bytes2
            )
        );

        address payable _wnftWallet = payable(factory.createWNFT(address(impl_legacy), initCallData));
        assertNotEq(_wnftWallet, address(impl_legacy));

        // send erc20 to wnft wallet
        erc20.transfer(_wnftWallet, sendERC20Amount);

        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);

        bytes memory _data = abi.encodeWithSignature("transfer(address,uint256)", address(11), sendERC20Amount / 2);

        // now time lock
        vm.expectRevert("TimeLock error");
        wnft.executeEncodedTx(address(erc20), 0, _data);

        // time lock has finished
        vm.warp(block.timestamp + 10001);
        vm.prank(address(1));
        vm.expectRevert("Only for wNFT owner");
        wnft.executeEncodedTx(address(erc20), 0, _data);

        wnft.executeEncodedTx(address(erc20), 0, _data);
        assertEq(erc20.balanceOf(address(11)), sendERC20Amount / 2);
        assertEq(erc20.balanceOf(address(_wnftWallet)), sendERC20Amount / 2);
    }
}
