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

## Finding #1 — CRITICAL — ERC-721 operator (`setApprovalForAll`) inherits **full asset-execution rights** on the wallet

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
  an `approve` or `setApprovalForAll` call. Wallet UIs surface this as
  "you are letting this contract move your NFT" — they do **not** warn
  about asset drains, because no other NFT design works this way.
- Impact: CRITICAL — full asset loss with no further action by victim.
- Pre-conditions: a single ERC-721 approval from victim to attacker.
  Approvals are the most common NFT-related onchain action.

### Fix direction

Decouple the "can move the NFT" capability from the "can execute on
the wallet" capability. The simplest, lowest-risk patch:

```solidity
function _wnftOwnerOrApproved(address _sender) internal view virtual {
    require(ownerOf(TOKEN_ID) == _sender, "Only for wNFT owner");
}
```

If second-party execution is genuinely required, introduce an explicit
`executionOperator` mapping that is **not** ERC-721 approval — owners
must opt in to wallet execution rights separately, exactly the same
way `trustedSigners` already work for the signature path. The
ERC-721 approval surface must not grant any rights beyond
`transferFrom`.

Also: ensure `safeTransferFrom` and `_update` clear stale execution
rights when ownership changes, so a buyer never inherits the seller's
operator set.

### PoC

`test/audit/WNFTV2Envelop721_Audit_a_01.t.sol`,
`test_approval_drains_wallet` — innocuous `setApprovalForAll` by the
owner, then attacker drains 100% of ERC20 + ETH out of the wallet.
Assertions:

```
assertEq(erc20.balanceOf(attacker),     initialDeposit);   // all USDC drained
assertEq(erc20.balanceOf(walletAddr),   0);
assertEq(attacker.balance,              initialEth);       // all ETH drained
assertEq(walletAddr.balance,            0);
assertEq(wnft.ownerOf(1),               aliceOwner);       // NFT never moved
```

---

## Finding #2 — HIGH — Approved relayer can drain `WNFTMyshchWallet` via gas-refund loop

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

### Fix direction

- Pin `_gasSpender = msg.sender` (or drop the parameter entirely and
  refund the relayer that did the work).
- Track the relayer's actual ETH outlay in `setGasCheckPoint`
  (`startBalance`) and refund only the delta they actually paid this
  tx, not a constant `PERMANENT_TX_COST`.
- Use `block.basefee` (or `tx.gasprice - block.basefee` capped) as the
  refund metric instead of raw `tx.gasprice`, so that priority-fee
  inflation can't blow up the refund.
- Add a per-relayer rate-limit (e.g. cumulative ETH refunded in a
  rolling window).

### PoC sketch

Out of scope of the test file shipped with this audit (the wallet's
approved-relayer set is administratively granted, so demonstrating
this is a "trusted role drains wallet" rather than a no-permission
exploit). The bug is still serious because the role's intended
authority is "be paid back for gas spent on the wallet's behalf",
which is materially narrower than "withdraw bounded ETH on demand to
any address".

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

| # | Severity | Title | PoC |
|---|----------|-------|-----|
| 1 | CRITICAL | ERC-721 approval grants asset-execution rights | `test/audit/WNFTV2Envelop721_Audit_a_01.t.sol::test_approval_drains_wallet` (+ `test_setApprovalForAll_drains_wallet`) |
| 2 | HIGH     | Approved relayer can drain via `getRefund` loop | sketch in finding |
| 3 | MEDIUM   | Trusted signers survive wNFT transfer / sale | sketch in finding |
| 4 | INFO     | `transferFrom` rule placement (OZ-5 path safe) | — |

Recommend blocking the 2.2.1 minor release on Finding #1.
