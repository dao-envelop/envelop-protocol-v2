# Specification: WNFTV2SmartIndex & EnvelopOracle extensions

## Overview

1. New interfaces `IIndexAssets` and `IAMMPriceAdapter` — callback and AMM price abstractions
2. New abstract contract `AbstractOnChainMetadata` — reusable on-chain SVG/JSON generation via virtual hooks
3. New wNFT implementation `WNFTV2SmartIndex` — on-chain `tokenURI`, index asset registry inside the wNFT proxy
4. Extensions to `EnvelopOracle` — auto-compute index price via callback, AMM support, ACL for Predicter

Does **not** modify `WNFTV2Index.sol`.

See implementation plan: [`codex/tasks/plan_index_dec.md`](plan_index_dec.md)

---

## 1. New interfaces

### 1.1 `src/interfaces/IIndexAssets.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IEnvelopOracle.sol";

interface IIndexAssets {
    /// @notice Returns the fixed portfolio of the index
    function getIndexAssets() external view returns (IEnvelopOracle.CompactAsset[] memory);

    /// @notice Returns the IAMMPriceAdapter address; address(0) = use Chainlink
    function getIndexAmm() external view returns (address);

    /// @notice Returns the base token for AMM pricing (e.g. USDC, WETH); address(0) = USD
    function getIndexBaseAsset() external view returns (address);
}
```

`WNFTV2SmartIndex` implements this. `EnvelopOracle` imports it for callbacks in `getIndexPrice(address)`.
No asset duplication — assets live only in the wNFT.

### 1.2 `src/interfaces/IAMMPriceAdapter.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @dev Adapter interface for AMM-based price sources.
 * Concrete adapters (UniswapV3Adapter, CurveAdapter, etc.) are deployed separately.
 * The adapter address is set as immutable AMM_ADAPTER in the WNFTV2SmartIndex constructor.
 * Each AMM requires a separate implementation deployment; the factory creates proxies from it.
 */
interface IAMMPriceAdapter {
    /**
     * @dev Returns USD value of `amount` units of `token` via the AMM.
     * @param token     ERC20 token address
     * @param amount    Token amount in native units (same as CompactAsset.amount)
     * @param baseAsset Intermediate token in the AMM pair (e.g. USDC, WETH).
     *                  Adapter resolves baseAsset → USD internally.
     * @return price    USD value
     * @return decimals Price decimals (may differ from Chainlink's 8)
     *
     * @notice MUST return a TWAP (time-weighted average price) with a minimum
     * window of 30 minutes — NOT a spot price. Spot-price adapters are vulnerable
     * to flash-loan manipulation at `fixIndex` time and are prohibited (see Constraint #14).
     */
    function getTokenPriceUSD(address token, uint96 amount, address baseAsset)
        external view returns (uint256 price, uint8 decimals);
}
```

---

## 2. `AbstractOnChainMetadata`

**File:** `src/impl/AbstractOnChainMetadata.sol`
**Inherits:** nothing (standalone abstract, imported by implementations)
**Pragma:** `^0.8.28`

Reusable abstract contract containing all JSON/SVG generation logic. Implementations provide data via virtual hooks.

### 2.1 Virtual hooks (must be overridden by implementations)

```solidity
/// @dev Name for the JSON "name" field
function _getMetadataName() internal view virtual returns (string memory);

/// @dev Version string for the JSON "indexVersion" field
function _getMetadataVersion() internal view virtual returns (string memory);

/// @dev The fixed portfolio of the index
function _getMetadataAssets() internal view virtual
    returns (IEnvelopOracle.CompactAsset[] memory);

/// @dev Oracle address for per-asset price queries
function _getMetadataOracle() internal view virtual returns (address);

/// @dev AMM adapter address; address(0) = Chainlink
function _getMetadataAmm() internal view virtual returns (address);

/// @dev Base asset for AMM pricing; address(0) = USD
function _getMetadataBaseAsset() internal view virtual returns (address);

/// @dev Start price (1e8 scale)
function _getMetadataStartPrice() internal view virtual returns (uint96);

/// @dev Current price (1e8 scale)
function _getMetadataCurrentPrice() internal view virtual returns (uint256);

/// @dev Locks array from wNFT data
function _getMetadataLocks() internal view virtual returns (ET.Lock[] memory);

/// @dev NFT symbol for SVG title
function _getMetadataSymbol() internal view virtual returns (string memory);

/// @dev Max collateral rows to display in SVG
function _getMetadataSvgMaxRows() internal view virtual returns (uint256);
```

### 2.2 Concrete methods (not virtual — shared logic)

```solidity
function _encodeBase64JSON(uint256 tokenId) internal view returns (string memory)
function _generateJSON(uint256 tokenId) internal view returns (string memory)
function _generateSVG(uint256 tokenId) internal view returns (string memory)
function _formatPrice(uint256 raw, uint8 dec) internal pure returns (string memory)
function _formatPriceDiff(uint256 start, uint256 current) internal pure returns (string memory)
function _chainName(uint256 chainId) internal pure returns (string memory)
```

All rendering logic calls the virtual hooks for data — never accesses storage directly.

> **External calls inside `_generateSVG` and `_generateJSON`** (`symbol()`, `balanceOf()`, `decimals()`, oracle price query) **MUST be wrapped in `try/catch`**. On failure fall back to `"?"` for symbol, `0` for balance/price. This prevents a single non-standard or paused token from making `tokenURI` permanently revert (see Constraint #15).

### 2.3 Imports

```solidity
import "../interfaces/IEnvelopOracle.sol";
import "../interfaces/IAMMPriceAdapter.sol";
import "../utils/LibET.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
```

### 2.4 SVG specification

**Canvas:** 300x500, `viewBox="0 0 300 500"`, `rx="20"`, no external resources.

**Gradient selection:**

| Condition | Gradient IDs |
|---|---|
| `_getMetadataAssets().length == 0` OR `_getMetadataCurrentPrice() >= _getMetadataStartPrice()` | `paint_linear_1`, `paint_linear_2` (green) |
| `_getMetadataAssets().length > 0 && _getMetadataCurrentPrice() < _getMetadataStartPrice()` | `paint_linear_1_red`, `paint_linear_2_red` (red) |

Both gradient definitions inlined in `<defs>`. Yellow variant reserved for future.

**Template variable mapping:**

| SVG element | Solidity expression |
|---|---|
| Animated border text | `"Index \u2022 " + Strings.toHexString(uint160(address(this)), 20)` |
| Title | `_getMetadataSymbol()` |
| Collateral rows | loop `i` in `0..min(_getMetadataSvgMaxRows(), assets.length)`: symbol via `IERC20Metadata(asset.token).symbol()`, balance via `IERC20(asset.token).balanceOf(address(this))` |
| Y-coordinate per row | `100 + i * 26` |
| "+ N more" row | if `assets.length > _getMetadataSvgMaxRows()`: N = `assets.length - _getMetadataSvgMaxRows()` |
| Empty state | shown if `_getMetadataAssets().length == 0`: "Waiting for assets..." |
| Start price | `"$" + _formatPrice(_getMetadataStartPrice(), 8)` |
| Current price | `"$" + _formatPrice(_getMetadataCurrentPrice(), 8)` |
| Price diff | `_formatPriceDiff(_getMetadataStartPrice(), _getMetadataCurrentPrice())` |
| Chain name | `_chainName(block.chainid)` |
| Chain ID | `Strings.toString(block.chainid)` |
| Token ID | `Strings.toString(tokenId)` |
| Date / Block | omitted (unavailable in `view`) |

**Helper: `_formatPrice(uint256 raw, uint8 dec) internal pure returns (string memory)`**

Renders `raw` as decimal string: integer part = `raw / 10**dec`, fractional = `raw % 10**dec` left-padded to `dec` digits, trailing zeros stripped.

**Helper: `_formatPriceDiff(uint256 start, uint256 current) internal pure returns (string memory)`**

Returns `"(+X.XX%)"` / `"(-X.XX%)"`. Returns `""` if `start == 0`.

**Helper: `_chainName(uint256 chainId) internal pure returns (string memory)`**

| chainId | name |
|---|---|
| 1 | "Ethereum" |
| 10 | "Optimism" |
| 56 | "BSC" |
| 100 | "Gnosis" |
| 137 | "Polygon" |
| 42161 | "Arbitrum" |
| 43114 | "Avalanche" |
| 81457 | "Blast" |
| default | `Strings.toString(chainId)` |

### 2.5 JSON specification

```json
{
  "name": "<_getMetadataName()>",
  "description": "Envelop Index wNFT",
  "indexVersion": "<_getMetadataVersion()>",
  "image": "data:image/svg+xml;base64,<Base64(_generateSVG(tokenId))>",
  "external_url": "https://app.envelop.is/token/<chainId>/<contractAddress>/<tokenId>",
  "attributes": [
    {"trait_type": "Start Price",   "value": <startPrice/1e8>,   "display_type": "number"},
    {"trait_type": "Current Price", "value": <currentPrice/1e8>, "display_type": "number"},
    {"trait_type": "Is Fixed",      "value": "<assets.length > 0>"},
    {"trait_type": "<symbol> Amount",    "value": <amount/10^decimals>, "display_type": "number"},
    {"trait_type": "<symbol> Price USD", "value": <price/1e8>,          "display_type": "number"}
  ],
  "collateral": [
    {
      "amount":          "<asset.amount as uint string>",
      "tokenId":         0,
      "assetType":       2,
      "contractAddress": "<asset.token lowercase hex>",
      "decimals":        <IERC20Metadata(asset.token).decimals()>,
      "price": {
        "base_asset":     "<_getMetadataBaseAsset(); address(0) = USD>",
        "price":          "<oracle/AMM price raw as uint string>",
        "price_decimals": "<Chainlink: 8; AMM: decimals from IAMMPriceAdapter>"
      }
    }
  ],
  "locks": [
    {"param": <lock.param>, "lockType": <uint8(lock.lockType)>}
  ],
  "updatedAt": <block.timestamp>
}
```

Notes:
- All data sourced exclusively via virtual hooks (§2.1) — no direct storage access
- `CompactAsset` is ERC20-only → `tokenId` always `0`, `assetType` always `2`
- If `_getMetadataAssets().length == 0`: `collateral = []`, price attribute values = `0`
- Locks accessed via `_getMetadataLocks()` virtual hook
- `price_decimals`: `8` for Chainlink path; value from `IAMMPriceAdapter` return for AMM path
- `base_asset`: from `_getMetadataBaseAsset()`
- Per-asset price: `IEnvelopOracle(_getMetadataOracle()).getPriceInUSD(asset.token)` if oracle set, else `"0"`

---

## 3. `WNFTV2SmartIndex`

**File:** `src/impl/WNFTV2SmartIndex.sol`
**Inherits:** `WNFTV2Envelop721`, `IIndexAssets`, `AbstractOnChainMetadata`
**Pragma:** `^0.8.28`

### 3.1 Constructor & immutables

```solidity
/// @notice IAMMPriceAdapter address; address(0) = Chainlink only
address public immutable AMM_ADAPTER;

constructor(address _defaultFactory, address _ammAdapter)
    WNFTV2Envelop721(_defaultFactory)
{
    AMM_ADAPTER = _ammAdapter;
}
```

Deploy once per AMM:
- `WNFTV2SmartIndex(factory, address(0))` — Chainlink pricing
- `WNFTV2SmartIndex(factory, uniV3Adapter)` — Uniswap V3
- `WNFTV2SmartIndex(factory, curveAdapter)` — Curve

The factory creates EIP-1167 proxies from the needed implementation.

### 3.2 Constants

```solidity
string  public constant nftName      = "Envelop wNFT V2 Smart Index";
string  public constant nftSymbol    = "ENVELOPV2";
string  public constant indexVersion = "2.1.0";
uint256 public constant MAX_ASSETS   = 100;  // portfolio cap (same as Predicter)
uint256 internal constant MAX_SVG_COLLATERAL_ROWS = 4;
```

### 3.3 Namespaced storage

```solidity
bytes32 private constant SMART_INDEX_STORAGE_LOCATION =
    keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTV2SmartIndex")) - 1))
    & ~bytes32(uint256(0xff));

struct SmartIndexStorage {
    // slot 0: dynamic array (always full slot)
    IEnvelopOracle.CompactAsset[] assets;
    // slot 1: oracle(20) + createdAt(5) = 25 bytes (7 free)
    // "is fixed" ≡ assets.length > 0 — no separate bool needed
    address oracle;
    uint40  createdAt;
    // slot 2: baseAsset(20) + startPrice(12) = 32 bytes exact
    address baseAsset;   // base token for AMM pricing (e.g. USDC, WETH)
                         // address(0) = USD denomination (Chainlink path)
    uint96  startPrice;  // 1e8 decimals; max ~7.9e20 USD
}
// 3 slots total. AMM adapter is immutable AMM_ADAPTER, not in storage.
// CompactAsset=(address,uint96) = 32 bytes per element.
// Index is "fixed" when assets.length > 0 (set once in fixIndex, never cleared).

function _getSmartIndexStorage() private pure returns (SmartIndexStorage storage $) {
    assembly { $.slot := SMART_INDEX_STORAGE_LOCATION }
}
```

### 3.4 Events

```solidity
event EnvelopIndexFixed(
    address indexed creator,
    uint96  startPrice,
    IEnvelopOracle.CompactAsset[] assets
);
```

### 3.5 Function: `fixIndex`

```solidity
function fixIndex(
    IEnvelopOracle.CompactAsset[] calldata _assets,
    address _oracle,
    address _baseAsset
) external onlyWnftOwner  // inherited from WNFTV2Envelop721: checks ownerOf(TOKEN_ID) == msg.sender
```

Execution order:
1. `require($.assets.length == 0, "Already fixed")` — `assets.length > 0` is the canonical "fixed" sentinel
2. `require(_assets.length > 0 && _assets.length <= MAX_ASSETS)`
3. Copy `_assets` into `$.assets`
4. `$.oracle = _oracle`, `$.baseAsset = _baseAsset`
5. `$.createdAt = uint40(block.timestamp)`
6. `IEnvelopOracle(_oracle).registerIndex()` — oracle registers `msg.sender`
7. `$.startPrice = SafeCast.toUint96(IEnvelopOracle(_oracle).getIndexPrice(address(this)))` — **AFTER** registration so oracle uses correct price source (AMM or Chainlink via callback)
8. Emit `EnvelopIndexFixed(msg.sender, $.startPrice, _assets)`

> **Lifecycle note:** `fixIndex` is a one-way transition. There is no `unfixIndex`. The only exit is `unwrap()` via the base `WNFTV2Envelop721` mechanism. To lock collateral permanently after fixation, set rule `No_Collateral` in the `InitParams` before or at creation time (see Constraint #17).

### 3.6 View functions

```solidity
function getCurrentPrice() public view returns (uint256)
```
- If `$.assets.length > 0 && $.oracle != address(0)`: return `IEnvelopOracle($.oracle).getIndexPrice(address(this))`
- Else: return `0`

```solidity
function getIndexRecord() external view returns (SmartIndexStorage memory)
```

### 3.7 `IIndexAssets` implementation

```solidity
function getIndexAssets() external view returns (IEnvelopOracle.CompactAsset[] memory) {
    return _getSmartIndexStorage().assets;
}

function getIndexAmm() external view returns (address) {
    return AMM_ADAPTER;  // immutable, not from storage
}

function getIndexBaseAsset() external view returns (address) {
    return _getSmartIndexStorage().baseAsset;
}
```

### 3.8 `tokenURI` override

```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return _encodeBase64JSON(tokenId); // from AbstractOnChainMetadata
}
```

### 3.9 `AbstractOnChainMetadata` virtual hook implementations

```solidity
function _getMetadataName()         internal pure  override returns (string memory) { return "Envelop Index"; }
function _getMetadataVersion()      internal pure  override returns (string memory) { return indexVersion; }
function _getMetadataAssets()       internal view  override returns (IEnvelopOracle.CompactAsset[] memory) { return _getSmartIndexStorage().assets; }
function _getMetadataOracle()       internal view  override returns (address) { return _getSmartIndexStorage().oracle; }
function _getMetadataAmm()          internal view  override returns (address) { return AMM_ADAPTER; }
function _getMetadataBaseAsset()    internal view  override returns (address) { return _getSmartIndexStorage().baseAsset; }
function _getMetadataStartPrice()   internal view  override returns (uint96)  { return _getSmartIndexStorage().startPrice; }
function _getMetadataCurrentPrice() internal view  override returns (uint256) { return getCurrentPrice(); }
function _getMetadataLocks()        internal view  override returns (ET.Lock[] memory) { return _getWNFTV2Envelop721Storage().wnftData.locks; }
function _getMetadataSymbol()       internal pure  override returns (string memory) { return nftSymbol; }
function _getMetadataSvgMaxRows()   internal pure  override returns (uint256) { return MAX_SVG_COLLATERAL_ROWS; }
```

### 3.10 Required imports

```solidity
import "./WNFTV2Envelop721.sol";
import "./AbstractOnChainMetadata.sol";
import "../interfaces/IEnvelopOracle.sol";
import "../interfaces/IIndexAssets.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
```

### 3.11 `name` / `symbol` / `supportsInterface` / factory overrides

```solidity
function name()   public pure override returns (string memory) { return nftName; }
function symbol() public pure override returns (string memory) { return nftSymbol; }

function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
    return interfaceId == type(IIndexAssets).interfaceId
        || super.supportsInterface(interfaceId);
}
```

`supportsInterface` declares `IIndexAssets` support so that `EnvelopOracle.registerIndex()` can validate the caller via ERC-165 (see Constraint #16).

Factory overrides clear `nftName`/`nftSymbol`/`tokenUri` before calling `super` (same pattern as `WNFTV2Index`).

### 3.12 Function: `setIndexUpdater`

```solidity
function setIndexUpdater(address _oracle, address _updater) external onlyWnftOwner {
    IEnvelopOracle(_oracle).setIndexUpdater(address(this), _updater);
}
```

Allows the wNFT owner to authorize an updater (e.g. `Predicter`) to call `oracle.setIndexPrice` on behalf of this index. Without this function the `authorizedUpdater` ACL in `EnvelopOracle` is unreachable from the wNFT owner.

### 3.13 Hook: `_beforeUnwrap` (oracle deregistration)

```solidity
function _beforeUnwrap(/* same signature as base */) internal override {
    SmartIndexStorage storage $ = _getSmartIndexStorage();
    if ($.assets.length > 0 && $.oracle != address(0)) {
        try IEnvelopOracle($.oracle).deregisterIndex() {} catch {}
    }
    super._beforeUnwrap(/* ... */);
}
```

Called by the base `WNFTV2Envelop721` unwrap flow before releasing collateral and burning the token. Clears the oracle registration so the zombie proxy is not queried after unwrap. The `try/catch` ensures that a failing oracle call never blocks unwrapping.

> **Sequence:** `unwrap()` → `_beforeUnwrap` → `oracle.deregisterIndex()` → collateral released → token burned.

---

## 4. Price source flow

```
fixIndex(_assets, _oracle, _baseAsset)
    │
    ├─► store assets, oracle, baseAsset in SmartIndexStorage (amm is immutable)
    ├─► assets.length > 0 now — index is "fixed"
    ├─► oracle.registerIndex()              // oracle marks msg.sender as registered
    └─► startPrice = oracle.getIndexPrice(address(this))
            │
            └─► oracle callback to wNFT:
                  assets    = wNFT.getIndexAssets()
                  amm       = wNFT.getIndexAmm()
                  baseAsset = wNFT.getIndexBaseAsset()
                  for each asset:
                    if amm != 0:
                      IAMMPriceAdapter(amm).getTokenPriceUSD(token, amount, baseAsset)
                    else:
                      Chainlink via _getLatestPriceInUSD(token)
```

`Predicter` can call `oracle.getIndexPrice(wNFT)` → same callback → same price source.

---

## 5. `EnvelopOracle` extensions

**File:** `src/utils/EnvelopOracle.sol`
**File:** `src/interfaces/IEnvelopOracle.sol`

### 5.1 New storage

```solidity
mapping(address wNFT => bool)    public isRegistered;
mapping(address wNFT => address) public authorizedUpdater; // e.g. Predicter
```

No `CompactAsset[]` storage — assets fetched via `IIndexAssets` callback.

### 5.2 New events

```solidity
event EnvelopIndexRegistered(address indexed wNFT);
event EnvelopIndexDeregistered(address indexed wNFT);
event EnvelopIndexPriceSet(address indexed wNFT, uint256 price, address indexed setter);
```

### 5.3 New functions

#### `registerIndex`

```solidity
function registerIndex() external
```
- `require(IERC165(msg.sender).supportsInterface(type(IIndexAssets).interfaceId), "Not IIndexAssets")` — rejects registrations from EOAs and contracts that do not implement the interface
- Sets `isRegistered[msg.sender] = true`
- Emits `EnvelopIndexRegistered(msg.sender)`

No parameters — the wNFT calls this, oracle registers `msg.sender`. Callers must implement `IIndexAssets` per ERC-165 (see Constraint #16). New import required: `import "@openzeppelin/contracts/utils/introspection/IERC165.sol"`.

#### `deregisterIndex`

```solidity
function deregisterIndex() external
```
- `require(isRegistered[msg.sender], "Not registered")`
- Sets `isRegistered[msg.sender] = false`
- Emits `EnvelopIndexDeregistered(msg.sender)`

Called by the wNFT via `_beforeUnwrap` (wrapped in `try/catch` on the wNFT side so a failing oracle never blocks unwrapping). After deregistration `getIndexPrice(wNFT)` returns `0`.

#### `setIndexUpdater`

```solidity
function setIndexUpdater(address _wNFT, address _updater) external
```
- Requires `msg.sender == _wNFT`
- Sets `authorizedUpdater[_wNFT] = _updater`

#### `setIndexPrice`

```solidity
function setIndexPrice(address _wNFT, uint256 _price) external
```
- Requires `msg.sender == authorizedUpdater[_wNFT]` OR `msg.sender == owner()`
- Sets `overridedPrices[_wNFT] = _price`
- Emits `EnvelopIndexPriceSet(_wNFT, _price, msg.sender)`

### 5.4 Modified `getIndexPrice(address _v2Index)`

```
Priority order:
1. overridedPrices[_v2Index] != 0
       → return overridedPrices[_v2Index]              // manual/Predicter override

2. isRegistered[_v2Index]
       → assets    = IIndexAssets(_v2Index).getIndexAssets()
         amm       = IIndexAssets(_v2Index).getIndexAmm()
         baseAsset = IIndexAssets(_v2Index).getIndexBaseAsset()
         uint256 total = 0
         for each asset:
           if amm != address(0):
             (price, dec) = IAMMPriceAdapter(amm).getTokenPriceUSD(
                                asset.token, asset.amount, baseAsset)
             // normalize to 1e8:
             if dec <= 8: total += price * 10**(8 - dec)
             else:        total += price / 10**(dec - 8)
           else:
             uint8 tokenDec = IERC20Metadata(asset.token).decimals()
             uint256 unitPrice = _getLatestPriceInUSD(asset.token) // 1e8
             // staleness check MUST be active (Constraint #13)
             total += unitPrice * uint256(asset.amount) / (10 ** uint256(tokenDec))
         return total  // always 1e8 scale

3. else → return 0
```

New imports for `EnvelopOracle.sol`:
```solidity
import "../interfaces/IIndexAssets.sol";
import "../interfaces/IAMMPriceAdapter.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
```

> **Staleness (Constraint #13):** The commented-out line in `_getLatestPriceInUSD` MUST be restored:
> ```solidity
> require(_updatedAt + MAX_STALE >= block.timestamp, "Price is stale");
> ```
> It was disabled in the existing code (`EnvelopOracle.sol:144`). It must be active for all uses of this oracle including `startPrice` computation in `fixIndex`.

### 5.5 Updated `IEnvelopOracle.sol`

Add to interface:

```solidity
function registerIndex() external;
function deregisterIndex() external;
function setIndexUpdater(address _wNFT, address _updater) external;
function setIndexPrice(address _wNFT, uint256 _price) external;
function isRegistered(address _wNFT) external view returns (bool);
```

> **Backward compatibility:** Adding functions to `IEnvelopOracle` is a breaking change for any consumer that declares a typed `IEnvelopOracle` variable. All call-sites must be recompiled against the updated interface. `EnvelopOracle.sol` must be redeployed on all chains; existing `overrideIndexPrice(address, uint256)` is preserved for owner-only manual overrides.

---

## 6. Constraints summary

| # | Constraint |
|---|---|
| 1 | No HTTP/IPFS in `tokenURI` output except `external_url` |
| 2 | `tokenURI` must be `view` — no state changes |
| 3 | SVG fully inline — no external resources |
| 4 | `fixIndex` callable once per wNFT (`require($.assets.length == 0)` guard; `assets.length > 0` is the canonical "fixed" sentinel — no separate `bool isFixed` field) |
| 5 | `assets.length <= MAX_ASSETS` enforced in `fixIndex` |
| 6 | SVG displays at most `MAX_SVG_COLLATERAL_ROWS` collateral rows |
| 7 | `registerIndex()` uses `msg.sender` — no parameter |
| 8 | `startPrice` stored as `uint96` via `SafeCast.toUint96` |
| 9 | AMM adapter returns `(price, decimals)` — oracle normalizes to 1e8 |
| 10 | `CompactAsset` is ERC20-only → collateral `tokenId=0`, `assetType=2` |
| 11 | Existing `EnvelopOracle` tests must continue to pass |
| 12 | `pragma solidity ^0.8.28`, OpenZeppelin v5 |
| 13 | Staleness check in `_getLatestPriceInUSD` MUST be active: `require(_updatedAt + MAX_STALE >= block.timestamp, "Price is stale")` (currently commented-out at `EnvelopOracle.sol:144`) |
| 14 | `IAMMPriceAdapter` implementations MUST return TWAP with ≥30 min window; spot-price adapters are prohibited |
| 15 | All external calls inside `tokenURI` (`symbol()`, `balanceOf()`, `decimals()`, oracle price) MUST be wrapped in `try/catch`; fall back to `"?"` / `0` on failure |
| 16 | `WNFTV2SmartIndex` MUST override `supportsInterface` to register `type(IIndexAssets).interfaceId` (required by `registerIndex` ERC-165 check) |
| 17 | No `unfixIndex` exists; fixation is permanent. The only lifecycle exit is `unwrap()` from the base `WNFTV2Envelop721` mechanism; `_beforeUnwrap` MUST call `oracle.deregisterIndex()` before collateral release. To freeze collateral after fixation, set rule `No_Collateral` in `InitParams`. |
