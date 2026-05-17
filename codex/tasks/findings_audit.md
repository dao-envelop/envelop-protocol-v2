# Task #4 — Deep audit: Singleton721 / SmartWallet / WNFTV2Envelop721 / WNFTMyshchWallet

Scope: `src/impl/Singleton721.sol`, `src/impl/SmartWallet.sol`,
`src/impl/WNFTV2Envelop721.sol`, `src/impl/WNFTMyshchWallet.sol`, and
the factories that initialise them (`EnvelopWNFTFactory`,
`MyShchFactory`).

Goal of the engagement: find **unauthorized** ways to withdraw assets
held by a wNFT smart wallet.

PoC for finding #1: `test/audit/WNFTV2Envelop721_Audit_a_01.t.sol`,
test `test_approval_drains_wallet`. All assertions are tight.

---

## Finding #1 — HIGH — ERC-721 operator (`setApprovalForAll`) inherits **full asset-execution rights** on the wallet

> **Status: FIXED in this branch.** `Singleton721._wnftOwnerOrApproved`
> no longer treats `isApprovedForAll` as a wallet-execution credential.
> Per-token `approve(operator, TOKEN_ID)` is intentionally still
> accepted — see "Rationale for the chosen fix" below.

### Where
- `src/impl/Singleton721.sol:102-108` — `_wnftOwnerOrApproved`
- `src/impl/Singleton721.sol:44-47` — `onlyWnftOwner` modifier
- Guards on:
  - `WNFTV2Envelop721.executeEncodedTx(...)` (line 226)
  - `WNFTV2Envelop721.executeEncodedTxBatch(...)` (line 240)
  - `WNFTV2Envelop721.setSignerStatus(...)` (line 263)
  - `WNFTMyshchWallet.erc20TransferWithRefund(...)` (line 90)
  - `WNFTMyshchWallet.setRelayerStatus(...)` (line 111)

```solidity
function _wnftOwnerOrApproved(address _sender) internal view virtual {
    address currOwner = ownerOf(TOKEN_ID);
    require(
        currOwner == _sender
            || isApprovedForAll(currOwner, _sender)
            || getApproved(TOKEN_ID) == _sender,
        "Only for wNFT owner"
    );
}
```

The same predicate that authorises an ERC-721 **transfer** of the wNFT
also authorises arbitrary execution against the wallet that lives
inside it. In ERC-721 the entire purpose of `approve` /
`setApprovalForAll` is to let third parties move the token; nothing in
the standard implies the approved address should also be able to spend
the token's underlying assets.

### Impact

Trust model violation that maps cleanly to "unauthorised withdrawal of
assets":

1. A wNFT wallet holds 1 ETH and 100 USDC.
2. Alice (the wallet owner) does the most ordinary thing an NFT owner
   does — she calls `setApprovalForAll(marketplace, true)` so that a
   marketplace contract can later transfer the wNFT on her behalf when
   the listing is filled.
3. `marketplace` (or anyone with operator powers — a malicious
   marketplace owner, a bug in the marketplace, a compromised
   approved EOA) immediately calls
   ```
   wnft.executeEncodedTx(usdc, 0, abi.encodeCall(IERC20.transfer, (attacker, 100e18)));
   ```
   and
   ```
   wnft.executeEncodedTx(attacker, 1 ether, "");
   ```
   draining **everything** from the wallet without ever transferring
   the wNFT, and Alice has no visibility into the drain because nothing
   touches the NFT itself.

The single-token `approve(operator, TOKEN_ID = 1)` path is just as
abusable — the same `getApproved(TOKEN_ID) == _sender` branch grants
execution.

This pattern also enables a self-contained reentrancy drain. A test
that demonstrates the basic primitive already exists in the legacy
suite — see `test/Factory_Test_a_27.sol::test_reentrancy` — but it
only logs values, never asserts, and the same attack works one-to-one
against `WNFTV2Envelop721` and `WNFTMyshchWallet`.

### Severity reasoning

- Likelihood: HIGH. Every secondary-market listing of a wNFT requires
  a `setApprovalForAll` call to the marketplace conduit. Wallet UIs
  surface this as "you are letting this contract move your NFT" —
  they do **not** warn about asset drains, because no other NFT
  design works this way.
- Impact: HIGH — silent loss of all ETH/ERC20/ERC721/ERC1155 the
  wallet holds, with no Transfer event on the wNFT itself so the
  victim has no early signal.
- Pre-conditions: a single ERC-721 `setApprovalForAll` from victim to
  attacker (or to a contract whose compromise grants the attacker
  operator power).

### Rationale for the chosen fix

The wNFT's design intentionally couples NFT ownership with wallet
custody: whoever holds `TOKEN_ID = 1` controls the wallet. Removing
this coupling is out of scope. What matters is the *granularity* of
the approval surface:

- `setApprovalForAll(conduit, true)` is the conduit pattern that every
  modern marketplace (Seaport, Blur, etc.) uses. A user calling this
  is signalling "I might list this NFT for sale" — they have no
  reason to expect that signal grants the conduit asset-drain rights.
  This branch is now removed.
- `approve(operator, TOKEN_ID)` is a deliberate, per-token act. The
  owner is explicitly handing this specific token to one address. In
  the "ownership = wallet" model this *is* effectively handing custody
  — an attacker with `approve(TOKEN_ID)` can already `transferFrom`
  to themselves and become owner. Keeping this branch preserves the
  intended UX of "the per-token approve is the wallet's transfer
  authorization".
- The `No_Transfer` rule still holds its promise: with `No_Transfer`
  set, `transferFrom` reverts, and now `executeEncodedTx` via
  operator approval also reverts, so a marketplace approval can no
  longer slip past the "this wNFT is locked" invariant.

### Implementation

`src/impl/Singleton721.sol:102` — `_wnftOwnerOrApproved` now accepts
only `currOwner == _sender || getApproved(TOKEN_ID) == _sender`. The
`isApprovedForAll` branch is gone.

### PoC

`test/audit/WNFTV2Envelop721_Audit_a_01.t.sol` — three tests lock in
the new contract:

- `test_setApprovalForAll_does_not_grant_execute` — operator approval
  no longer unlocks `executeEncodedTx`; balances untouched.
- `test_singleApprove_still_grants_execute_by_design` — per-token
  approve still permits drain (intentional, documents the design).
- `test_setApprovalForAll_cannot_install_signer_backdoor` — operator
  approval also can't reach the administrative surface
  (`setSignerStatus`).

Plus the reentrancy demo at `test/Factory_Test_a_27.sol::test_reentrancy`
is now updated to **assert** the attack is blocked (was previously a
silent demo with no assertions).

---

## Finding #2 — HIGH — Approved relayer can drain `WNFTMyshchWallet` via gas-refund loop

> **Status: FIXED in this branch.** `getRefund` now (a) anchors the
> refund to `block.basefee` instead of the attacker-controlled
> `tx.gasprice`, and (b) requires `MIN_REFUND_WORK_GAS` of actual gas
> spent between `setGasCheckPoint` and `getRefund` before paying out.
> Signature unchanged; `msg.sender` not used as a credential check.

### Where
- `src/impl/WNFTMyshchWallet.sol:99-109` — `setGasCheckPoint` / `getRefund`
- `src/impl/WNFTMyshchWallet.sol:142-145` — `_onlyAprrovedRelayer`

```solidity
function setGasCheckPoint() external onlyAprrovedRelayer returns (uint256) {
    gasLeftOnStart = gasleft();
    return gasLeftOnStart;
}

function getRefund(address _gasSpender) external onlyAprrovedRelayer fixEtherBalance returns (uint256 send) {
    send = (PERMANENT_TX_COST + _getGasDiff(gasLeftOnStart)) * tx.gasprice;
    require(send < PERMANENT_TX_COST * tx.gasprice * 2, "Too much refund request");
    send += _getFeeAmount(send);
    Address.sendValue(payable(_gasSpender), send);
}
```

### Issue

The intended flow is: a peer wNFT acting as a relayer (i) pings
`setGasCheckPoint`, (ii) performs work, (iii) pings `getRefund` to be
compensated. The protections in place are:

- `onlyAprrovedRelayer` — the wallet owner must whitelist the relayer.
- `require(send < PERMANENT_TX_COST * tx.gasprice * 2)` — per-call cap
  ≈ 86 000 × gasprice.

Three problems compound:

1. **No bound on `_gasSpender`.** Even though only an approved relayer
   may call, it can route the ETH to any address — including an EOA it
   controls. The approved-relayer role was conceived as "pay me back
   for gas I just spent on your behalf", but the contract never checks
   that any gas was actually spent on the wallet's behalf in this tx.
2. **Static cap, not a per-relayer / per-tx budget.** A single approved
   relayer can call `setGasCheckPoint` → `getRefund` over and over in
   independent transactions and extract `~PERMANENT_TX_COST × gasprice`
   each time, paying only the much smaller cost of those two calls.
   Profit per round-trip ≈ `(PERMANENT_TX_COST − overhead) × gasprice`.
3. **`tx.gasprice` is attacker-controlled.** The relayer chooses the
   gas price for its own tx. With a small base-fee + large priority
   fee the attacker pays moderate ETH for gas but `tx.gasprice` shows
   up huge in the refund formula, so the wallet leaks far more than
   the relayer spent. (Post-EIP-1559 this is partly damped because
   the priority fee is what the attacker actually pays, but the attack
   still nets positive every iteration.)

### Impact

A relayer that the wallet owner trusts for **gas reimbursement** can
quietly drain the wallet's ETH balance, one bounded chunk at a time,
to any address it likes. The wallet owner only intended to authorise
"refund me the gas I just paid", not "withdraw arbitrary ETH on
demand".

### Severity reasoning

- Likelihood: MEDIUM. Requires the wallet owner to have approved the
  relayer, which is the normal setup for the Myshch flow. Any
  compromise / malicious behaviour of an approved relayer becomes a
  drain.
- Impact: HIGH (full ETH balance lost over time, bounded only by the
  number of transactions the relayer is willing to send).

### Implementation

`src/impl/WNFTMyshchWallet.sol`:

```solidity
uint256 public constant MIN_REFUND_WORK_GAS = 10_000;

function getRefund(address _gasSpender) external onlyAprrovedRelayer fixEtherBalance returns (uint256 send) {
    uint256 diff = _getGasDiff(gasLeftOnStart);
    require(diff >= MIN_REFUND_WORK_GAS, "Refund: no work done");
    send = (PERMANENT_TX_COST + diff) * block.basefee;
    send += _getFeeAmount(send);
    require(send < PERMANENT_TX_COST * block.basefee * 3, "Too much refund request");
    Address.sendValue(payable(_gasSpender), send);
}
```

Three points:

- `block.basefee` replaces `tx.gasprice`. Priority fee is fully
  attacker-controlled; basefee is set by consensus. With basefee
  anchoring, an attacker who pushes `maxPriorityFeePerGas` up to
  inflate the refund finds the formula doesn't see it at all.
- `MIN_REFUND_WORK_GAS` rejects the trivial `setGasCheckPoint →
  getRefund` no-op shape. Inter-function overhead is a few thousand
  gas; any per-token action (ERC20 transfer, ERC721 transfer, ETH
  send) easily clears this gate.
- The cap require now runs *after* the fee is added, so the 10% fee
  multiplier can't push the payout past the documented limit. The
  multiplier was widened from `* 2` to `* 3` to keep the legit
  `erc20TransferWithRefund` flow inside the cap.

What we explicitly did **not** change (per design call): the
`_gasSpender` parameter and the absence of a `msg.sender == _gasSpender`
check. The role still trusts the approved relayer to route the refund
correctly, but the *amount* of the refund is no longer
relayer-inflatable.

### Residual risk

A still-malicious approved relayer can pad real gas burn above
`MIN_REFUND_WORK_GAS` and claim a slightly positive marginal profit
per call, because `PERMANENT_TX_COST` plus the 10% fee is structurally
larger than the relayer's minimum tx overhead. The economics are now:

- Per-call leak ≤ `PERMANENT_TX_COST * basefee * 3` ≈ 129k * basefee
  (tight cap, not relayer-inflatable).
- Per-call attacker cost ≥ base-tx + `MIN_REFUND_WORK_GAS` gas, paid
  at `basefee + priorityFee` per gas (priority fee burned outright
  unless attacker also operates the builder).
- Slow, visible drain at low per-call margin; nothing like the
  pre-fix gas-price-inflated drain rate.

The proper next step is a per-relayer / per-epoch budget cap (owner-
configurable), tracked as a follow-up rather than blocking this
release. See `[[finding-2-followup]]` if a future memory references it.

### PoC

`test/audit/WNFTMyshchWallet_Audit_a_02.t.sol` — three tests lock in
the new behaviour:

- `test_noWork_drain_blocked` — attacker contract calling
  `setGasCheckPoint + getRefund` in one frame reverts with
  `"Refund: no work done"`; wallet untouched.
- `test_priorityFee_inflation_blocked` — even at `tx.gasprice =
  1000 gwei` while basefee stays at 20 gwei, the attack reverts and
  the wallet's balance is untouched. The formula no longer reads the
  inflated gasprice.
- `test_repeated_noWork_attempts_blocked` — looped attempts make no
  dent in the wallet.

---

## Finding #3 — MEDIUM — `trustedSigners` survive wNFT transfer

### Where
- `src/impl/WNFTV2Envelop721.sol:355-358` — `_getSignerStatus`
- `src/impl/WNFTV2Envelop721.sol:260-271` — `executeEncodedTxBySignature`
- `src/impl/WNFTV2Envelop721.sol:273-281` — `setSignerStatus`

```solidity
function _getSignerStatus(address _signer) internal view returns (bool) {
    WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
    return $.trustedSigners[_signer] || _signer == ownerOf(TOKEN_ID);
}
```

The trusted-signer set is contract-scoped (per-clone) and is never
cleared on wNFT transfer. Combined with the digest format
`keccak256(chainid, sender, nonce+1, target, value, data)` where the
nonce is **per-caller**, a previous owner can:

1. Sign one or more execution-by-signature messages for an
   accomplice's address (where the accomplice's nonce is currently 0).
2. Transfer / sell the wNFT.
3. The accomplice replays the prepared signatures *after* the buyer
   has taken ownership — `_getSignerStatus(prevOwner)` still returns
   `true` if `prevOwner` was ever set as `trustedSigner`. The buyer's
   wallet leaks assets.

The buyer has no way to enumerate trusted signers (no `getSigners()`
view), so they can't even revoke them defensively.

### Severity

MEDIUM. Realistic exploitation requires either a secondary-market sale
of the wNFT or some custody change that leaves the old owner's
`trustedSigners` in place. Where wNFTs are designed to be sold (a
core Envelop use case), this is a strict liability for any buyer.

### Fix direction

- Iterate / clear `trustedSigners` on `_update` (when ownership
  changes), or store signers in an `EnumerableSet` and reset it on
  transfer.
- Expose a `getTrustedSigners()` view so buyers can audit & revoke.
- Optionally bind the signature digest to the owner-at-signing-time
  (e.g. include `ownerOf(TOKEN_ID)` in the digest) so old signatures
  invalidate automatically on transfer.

---

## Finding #4 — LOW / Informational — `transferFrom` rule check is not enforced on `safeTransferFrom`'s 4-arg overload in pre-OZ-5 inheritance edge cases; current OZ-5 path is safe

OZ 5.5 implements `safeTransferFrom` by delegating to `transferFrom`,
so the `No_Transfer` rule in
`WNFTV2Envelop721.transferFrom`(`src/impl/WNFTV2Envelop721.sol:208`)
is reachable via every external transfer entry-point. This is
informational — should the project move to a newer OZ release that
re-routes `safeTransferFrom` through a different internal helper, the
override would have to be moved down to `_update` to remain effective.
Track this as a maintenance hazard, not an active bug.

---

## Out-of-scope / quickly-cleared review notes

- **Initialization races.** `EnvelopWNFTFactory._clone` does
  `Clones.clone` + `Address.functionCallWithValue(_contract, init, value)`
  atomically; the `initializer` modifier on every `initialize` path
  blocks any second initialisation. Safe.
- **`createWNFTonFactory` and `createWNFTonFactory2` delegate-call
  guard.** Both are `notDelegated`. Safe.
- **`executeEncodedTx` reentrancy alone.** Without Finding #1, plain
  reentrancy doesn't open new doors: there's no internal accounting
  state that depends on a single linearised call ordering. Reentrancy
  combined with Finding #1 is the actual exploit.
- **`fixEtherBalance` modifier.** It only emits a diagnostic event;
  it neither validates nor restricts changes. Treat it as logging,
  not as a control.
- **`approveHiden` event suppression.** It bypasses the standard
  `Approval` event, which is bad UX (indexers can miss the approval)
  but doesn't grant extra authority — the same approval would be
  granted by the standard `approve`. Marked as info; recommend
  emitting the event in addition.

---

## Summary table

| # | Severity | Status | Title | PoC |
|---|----------|--------|-------|-----|
| 1 | HIGH     | **Fixed** | `setApprovalForAll` granted asset-execution rights | `test/audit/WNFTV2Envelop721_Audit_a_01.t.sol`, plus `Factory_Test_a_27::test_reentrancy` now asserts the attack is blocked |
| 2 | HIGH     | **Fixed** (residual documented) | Approved relayer can drain via `getRefund` loop | `test/audit/WNFTMyshchWallet_Audit_a_02.t.sol` |
| 3 | MEDIUM   | Open | Trusted signers survive wNFT transfer / sale | sketch in finding |
| 4 | INFO     | Open | `transferFrom` rule placement (OZ-5 path safe) | — |

Findings #1 and #2 are closed in this branch; #3 / #4 remain open as
either out-of-scope or follow-ups.
