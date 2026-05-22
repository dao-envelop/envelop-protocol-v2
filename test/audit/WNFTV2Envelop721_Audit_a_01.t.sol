// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {EnvelopWNFTFactory} from "../../src/EnvelopWNFTFactory.sol";
import {MockERC20} from "../../src/mock/MockERC20.sol";
import {WNFTV2Envelop721} from "../../src/impl/WNFTV2Envelop721.sol";

/// @dev Task #4, Finding #1 (HIGH, fixed): operator-style ERC-721 approval
/// (`setApprovalForAll`) used to inherit full wallet-execution rights on the
/// wNFT. Combined with the conduit pattern that every modern NFT
/// marketplace (Seaport / Blur / etc.) relies on, that made a single
/// "list my NFT" approval enough to drain every asset held inside.
///
/// This test suite locks in the fix in `Singleton721._wnftOwnerOrApproved`:
/// - `setApprovalForAll(operator, true)` no longer grants execution rights.
/// - per-token `approve(operator, TOKEN_ID)` still does — that's the
///   intentional "ownership transfers full custody" semantics of the
///   wNFT-wallet, and it's a deliberate per-token act by the owner.
contract WNFTV2Envelop721_Audit_a_01 is Test {
    address internal alice; // wNFT owner / would-be victim
    address internal attacker; // address that gets innocuously approved

    EnvelopWNFTFactory internal factory;
    WNFTV2Envelop721 internal impl;
    WNFTV2Envelop721 internal wnft; // proxy clone
    MockERC20 internal erc20;

    uint256 internal constant INIT_ERC20_DEPOSIT = 100 ether;
    uint256 internal constant INIT_ETH_DEPOSIT = 1 ether;

    receive() external payable {}

    function setUp() public {
        alice = makeAddr("alice");
        attacker = makeAddr("attacker");

        vm.deal(address(this), 10 ether);
        vm.deal(alice, 10 ether);

        factory = new EnvelopWNFTFactory();
        impl = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(impl), true);

        erc20 = new MockERC20("Mock", "MOCK");

        WNFTV2Envelop721.InitParams memory init = WNFTV2Envelop721.InitParams({
            creator: alice,
            nftName: "Envelop Wallet",
            nftSymbol: "ENVW",
            tokenUri: "",
            addrParams: new address[](0),
            hashedParams: new bytes32[](0),
            numberParams: new uint256[](0),
            bytesParam: ""
        });

        vm.prank(alice);
        address payable wnftAddr = payable(impl.createWNFTonFactory(init));
        wnft = WNFTV2Envelop721(wnftAddr);

        erc20.transfer(address(wnft), INIT_ERC20_DEPOSIT);
        (bool ok,) = address(wnft).call{value: INIT_ETH_DEPOSIT}("");
        require(ok, "seed eth failed");

        assertEq(wnft.ownerOf(1), alice, "setUp: owner");
        assertEq(erc20.balanceOf(address(wnft)), INIT_ERC20_DEPOSIT, "setUp: erc20 in wallet");
        assertEq(address(wnft).balance, INIT_ETH_DEPOSIT, "setUp: eth in wallet");
    }

    /// @dev Post-fix: `setApprovalForAll` no longer hands the wallet keys to
    /// the operator. Calling executeEncodedTx as the operator must revert
    /// and the wallet's balances must be untouched.
    function test_setApprovalForAll_does_not_grant_execute() public {
        vm.prank(alice);
        wnft.setApprovalForAll(attacker, true);

        bytes memory erc20Payload =
            abi.encodeWithSignature("transfer(address,uint256)", attacker, INIT_ERC20_DEPOSIT);

        vm.prank(attacker);
        vm.expectRevert("Only for wNFT owner");
        wnft.executeEncodedTx(address(erc20), 0, erc20Payload);

        vm.prank(attacker);
        vm.expectRevert("Only for wNFT owner");
        wnft.executeEncodedTx(attacker, INIT_ETH_DEPOSIT, "");

        // Wallet still intact.
        assertEq(erc20.balanceOf(address(wnft)), INIT_ERC20_DEPOSIT, "erc20 untouched");
        assertEq(address(wnft).balance, INIT_ETH_DEPOSIT, "eth untouched");
        assertEq(erc20.balanceOf(attacker), 0, "attacker got no erc20");
        assertEq(attacker.balance, 0, "attacker got no eth");
    }

    /// @dev Post-fix: per-token `approve(operator, TOKEN_ID)` STILL grants
    /// full execution rights. This is intentional — single-token approval
    /// is a deliberate, per-token act by the owner and matches the wNFT
    /// design that ownership of the token equals ownership of the wallet
    /// (an attacker holding `approve(TOKEN_ID)` could anyway `transferFrom`
    /// to themselves and become owner, except where the No_Transfer rule is
    /// set).
    function test_singleApprove_still_grants_execute_by_design() public {
        vm.prank(alice);
        wnft.approve(attacker, 1); // TOKEN_ID == 1

        bytes memory erc20Payload =
            abi.encodeWithSignature("transfer(address,uint256)", attacker, INIT_ERC20_DEPOSIT);

        vm.prank(attacker);
        wnft.executeEncodedTx(address(erc20), 0, erc20Payload);

        vm.prank(attacker);
        wnft.executeEncodedTx(attacker, INIT_ETH_DEPOSIT, "");

        assertEq(erc20.balanceOf(attacker), INIT_ERC20_DEPOSIT, "single-approve still permits drain");
        assertEq(attacker.balance, INIT_ETH_DEPOSIT, "single-approve still permits eth drain");
        assertEq(wnft.ownerOf(1), alice, "wNFT itself was never transferred");
    }

    /// @dev Post-fix: setApprovalForAll also can't install a permanent
    /// backdoor via `setSignerStatus`. The whole administrative surface
    /// guarded by `onlyWnftOwner` is now off-limits to operator-style
    /// approvals.
    function test_setApprovalForAll_cannot_install_signer_backdoor() public {
        vm.prank(alice);
        wnft.setApprovalForAll(attacker, true);

        vm.prank(attacker);
        vm.expectRevert("Only for wNFT owner");
        wnft.setSignerStatus(attacker, true);

        assertFalse(wnft.getSignerStatus(attacker), "attacker is NOT a trusted signer");
    }
}
