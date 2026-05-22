// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {EnvelopWNFTFactory} from "../../src/EnvelopWNFTFactory.sol";
import {WNFTMyshchWallet} from "../../src/impl/WNFTMyshchWallet.sol";
import {WNFTV2Envelop721} from "../../src/impl/WNFTV2Envelop721.sol";

/// @dev Task #4, Finding #2 (HIGH, fixed): an approved relayer used to be
/// able to drain `WNFTMyshchWallet` via `getRefund`. Two attack vectors:
///
///   (a) Trivial no-op claim: relayer calls `setGasCheckPoint` →
///       `getRefund(self)` back-to-back with no real work in between, and
///       still pockets the static `PERMANENT_TX_COST * tx.gasprice` chunk
///       of the refund. Profit per tx is small but strictly positive, so
///       the wallet eventually empties.
///
///   (b) Priority-fee inflation: `tx.gasprice` is attacker-controlled.
///       By setting a huge `maxPriorityFeePerGas`, the relayer makes the
///       wallet refund a much bigger ETH amount than they actually spent
///       on gas — particularly devastating if the relayer is, or
///       collaborates with, the block builder and recovers the priority
///       fee.
///
/// Fix:
///   - `getRefund` now anchors the refund to `block.basefee`, which the
///     relayer cannot inflate.
///   - A `MIN_REFUND_WORK_GAS` gate (≈ 10k gas) rejects refunds when the
///     relayer didn't actually spend gas on the wallet's behalf in this
///     call frame.
///
/// This file locks both protections in.
contract WNFTMyshchWallet_Audit_a_02 is Test {
    address internal owner;
    address internal relayer;

    EnvelopWNFTFactory internal factory;
    WNFTMyshchWallet internal impl;
    WNFTMyshchWallet internal wallet;

    Attacker internal attacker;

    uint256 internal constant WALLET_ETH = 1 ether;

    receive() external payable {}

    function setUp() public {
        owner = makeAddr("walletOwner");
        relayer = makeAddr("relayer");

        vm.deal(owner, 10 ether);
        vm.deal(relayer, 10 ether);

        factory = new EnvelopWNFTFactory();
        impl = new WNFTMyshchWallet(address(factory));
        factory.setWrapperStatus(address(impl), true);

        WNFTV2Envelop721.InitParams memory init = WNFTV2Envelop721.InitParams({
            creator: owner,
            nftName: "Myshch",
            nftSymbol: "MSW",
            tokenUri: "",
            addrParams: new address[](0),
            hashedParams: new bytes32[](0),
            numberParams: new uint256[](0),
            bytesParam: ""
        });

        vm.prank(owner);
        wallet = WNFTMyshchWallet(payable(impl.createWNFTonFactory(init)));

        // Owner whitelists the relayer.
        vm.prank(owner);
        wallet.setRelayerStatus(relayer, true);

        // Fund the wallet so refund actually has something to send.
        (bool ok,) = address(wallet).call{value: WALLET_ETH}("");
        require(ok, "seed");

        attacker = new Attacker(wallet);

        // Approved relayer power for the attacker contract, simulating a
        // compromised / malicious relayer.
        vm.prank(owner);
        wallet.setRelayerStatus(address(attacker), true);
    }

    /// @dev Vector (a): the bare-bones no-work drain. Attacker calls
    /// `setGasCheckPoint` and immediately `getRefund` inside one of their
    /// own functions. With the fix, MIN_REFUND_WORK_GAS rejects this and
    /// the wallet's balance is untouched.
    function test_noWork_drain_blocked() public {
        uint256 walletBefore = address(wallet).balance;
        uint256 attackerBefore = address(attacker).balance;

        // Realistic onchain conditions: non-zero basefee, attacker tx
        // uses a moderate gas price.
        vm.fee(20 gwei);
        vm.txGasPrice(20 gwei);

        vm.expectRevert("Refund: no work done");
        attacker.drainNoWork(address(this));

        assertEq(address(wallet).balance, walletBefore, "wallet untouched");
        assertEq(address(attacker).balance, attackerBefore, "attacker got nothing");
    }

    /// @dev Vector (b): priority-fee inflation. Attacker sets
    /// `tx.gasprice` to ~1000 gwei while basefee stays at 20 gwei. Pre-fix,
    /// the wallet would refund based on the inflated `tx.gasprice`. Post-
    /// fix, the refund is anchored to `block.basefee`, so the attacker
    /// can't scale up the leak — and the no-work guard blocks the
    /// trivial flow anyway, so the attack flat-out reverts. Either way,
    /// the wallet's balance must remain intact.
    function test_priorityFee_inflation_blocked() public {
        uint256 walletBefore = address(wallet).balance;

        vm.fee(20 gwei);
        vm.txGasPrice(1000 gwei); // attacker tries to inflate refund 50x

        vm.expectRevert("Refund: no work done");
        attacker.drainNoWork(address(this));

        assertEq(address(wallet).balance, walletBefore, "wallet untouched even at inflated tx.gasprice");
    }

    /// @dev Spam-the-loop attempt: many tries shouldn't make a dent. Even
    /// if the attacker padded their tx with real gas to clear the
    /// MIN_REFUND_WORK_GAS gate, `block.basefee` puts a hard ceiling on
    /// the per-call leak that doesn't grow with attacker-chosen
    /// gasprice. We verify the no-work loop continues to revert.
    function test_repeated_noWork_attempts_blocked() public {
        uint256 walletBefore = address(wallet).balance;

        vm.fee(20 gwei);
        vm.txGasPrice(20 gwei);

        for (uint256 i = 0; i < 5; ++i) {
            vm.expectRevert("Refund: no work done");
            attacker.drainNoWork(address(this));
        }

        assertEq(address(wallet).balance, walletBefore, "wallet untouched after spam");
    }
}

/// @notice Helper that simulates an approved relayer trying to claim a
/// refund without doing any work on the wallet's behalf. The single
/// function pattern (`setGasCheckPoint → getRefund`) is the realistic
/// attack shape — both calls are in the same call frame, so `_getGasDiff`
/// only sees the inter-function overhead and falls below
/// MIN_REFUND_WORK_GAS.
contract Attacker {
    WNFTMyshchWallet immutable wallet;

    constructor(WNFTMyshchWallet _wallet) {
        wallet = _wallet;
    }

    receive() external payable {}

    function drainNoWork(address _gasSpender) external {
        wallet.setGasCheckPoint();
        wallet.getRefund(_gasSpender);
    }
}
