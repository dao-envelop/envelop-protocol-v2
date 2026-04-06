# Specification: WNFTV2SmartIndex & EnvelopOracle extensions

## Overview

Specification for:
1. New wNFT implementation `WNFTV2SmartIndex` — on-chain `tokenURI` + index asset registry inside the wNFT proxy
2. New interface `IAMMPriceAdapter` — abstraction over AMM price sources
3. Extensions to `EnvelopOracle` — auto-compute index price from registered assets, AMM price source support, ACL for Predicter

This spec does **not** modify `WNFTV2Index.sol`.

---

## 1. `IAMMPriceAdapter` interface

**File:** `src/interfaces/IAMMPriceAdapter.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @dev Adapter interface for AMM-based price sources.
 * Each supported DEX (Uniswap V3, Curve, etc.) is wrapped in a concrete
 * adapter contract that implements this interface.
 * The adapter address is stored in the index as the `amm` field and registered
 * in EnvelopOracle. This decouples the oracle from any specific DEX interface.
 */
interface IAMMPriceAdapter {
    /**
     * @dev Returns the USD value of `amount` units of `token` via the AMM.
     * @param token   ERC20 token address
     * @param amount  Token amount in native units (same as CompactAsset.amount)
     * @return        USD value with 1e8 decimals (same scale as Chainlink)
     */
    function getTokenPriceUSD(address token, uint96 amount) external view returns (uint256);
}
```

The `amm` field in the index stores an `IAMMPriceAdapter` adapter address — **not** the raw DEX address. Concrete adapters are deployed separately. This allows reusing the same adapter for multiple indexes on the same DEX.

---

## 2. `WNFTV2SmartIndex`

**File:** `src/impl/WNFTV2SmartIndex.sol`  
**Inherits:** `WNFTV2Envelop721`  
**Pragma:** `^0.8.28`

### 2.1 Constants

```solidity
string public constant nftName      = "Envelop wNFT V2 Smart Index";
string public constant nftSymbol    = "ENVELOPV2";
string public constant indexVersion = "2.1.0";
```

### 2.2 Namespaced storage

```solidity
bytes32 private constant SMART_INDEX_STORAGE_LOCATION =
    keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTV2SmartIndex")) - 1))
    & ~bytes32(uint256(0xff));

struct SmartIndexStorage {
    IEnvelopOracle.CompactAsset[] assets; // fixed portfolio (token addr + amount)
    address oracle;   // IEnvelopOracle implementation used for pricing
    address amm;      // IAMMPriceAdapter address; address(0) = use Chainlink in oracle
    uint256 startPrice; // total portfolio USD price at fixation, 1e8 decimals
    uint40  createdAt;  // block.timestamp of fixIndex() call
    bool    isFixed;    // once true: assets/startPrice cannot change
}
```

Accessor:
```solidity
function _getSmartIndexStorage() private pure returns (SmartIndexStorage storage $) {
    assembly { $.slot := SMART_INDEX_STORAGE_LOCATION }
}
```

### 2.3 Events

```solidity
event IndexFixed(
    address indexed creator,
    uint256 startPrice,
    IEnvelopOracle.CompactAsset[] assets,
    address oracle,
    address amm   // IAMMPriceAdapter, or address(0)
);
```

### 2.4 Function: `fixIndex`

```solidity
function fixIndex(
    IEnvelopOracle.CompactAsset[] calldata _assets,
    address _oracle,
    address _amm        // IAMMPriceAdapter address, or address(0) to use Chainlink
) external onlyWnftOwner
```

Execution:
1. Require `!$.isFixed` — revert `"Already fixed"`
2. Require `_assets.length > 0`
3. Copy `_assets` into `$.assets`
4. Write `$.oracle = _oracle`, `$.amm = _amm`
5. Call `IEnvelopOracle(_oracle).getIndexPrice(_assets)` → store in `$.startPrice`
6. Set `$.createdAt = uint40(block.timestamp)`, `$.isFixed = true`
7. Call `IEnvelopOracle(_oracle).registerIndex(address(this), _assets, _amm)` — registers portfolio + AMM source in oracle
8. Emit `IndexFixed(msg.sender, $.startPrice, _assets, _oracle, _amm)`

**Rationale for AMM parameter**: For option-style indexes the settlement price must come from the specific DEX where the swap will execute. Passing `_amm` (an `IAMMPriceAdapter`) to `fixIndex` and forwarding it to the oracle ensures that both `getCurrentPrice()` and `Predicter` resolution use the same price source as the actual settlement.

### 2.5 Function: `getCurrentPrice`

```solidity
function getCurrentPrice() public view returns (uint256)
```

- If `isFixed && oracle != address(0)`: return `IEnvelopOracle(oracle).getIndexPrice(address(this))`
- Else: return `0`

The oracle resolves the price using the registered AMM adapter or Chainlink depending on what was passed at `fixIndex` time (see §4.4).

### 2.6 View functions

```solidity
function getIndexRecord() external view returns (SmartIndexStorage memory)
```

### 2.7 `tokenURI` and helpers

```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory)
```
Returns `_encodeBase64JSON(tokenId)`.

```solidity
function _encodeBase64JSON(uint256 tokenId) internal view returns (string memory)
```
```solidity
return string.concat(
    "data:application/json;base64,",
    Base64.encode(bytes(_generateJSON(tokenId)))
);
```

```solidity
function _generateJSON(uint256 tokenId) internal view returns (string memory)
```
Assembles full JSON. See §2.10.

```solidity
function _generateSVG(uint256 tokenId) internal view returns (string memory)
```
Assembles full SVG string. See §2.9.

### 2.8 Required imports

```solidity
import "./WNFTV2Envelop721.sol";
import "../interfaces/IEnvelopOracle.sol";
import "../interfaces/IAMMPriceAdapter.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
```

### 2.9 SVG specification

**Canvas:** 300×500, `viewBox="0 0 300 500"`, `rx="20"`, no external resources.

**Gradient selection** (evaluated at render time):

| Condition | Gradient IDs |
|---|---|
| `!isFixed` OR `getCurrentPrice() >= startPrice` | `paint_linear_1`, `paint_linear_2` (green) |
| `isFixed && getCurrentPrice() < startPrice` | `paint_linear_1_red`, `paint_linear_2_red` (red) |

Both gradient definitions (green + red, as in `default.svg`) must be inlined in `<defs>`. Yellow variant is reserved for future use.

**Template variable mapping:**

| SVG element | Solidity expression |
|---|---|
| Animated border text | `"Index \u2022 " + Strings.toHexString(uint160(address(this)), 20)` |
| Title | `symbol()` |
| Collateral row symbol | `IERC20Metadata(asset.token).symbol()` |
| Collateral row balance | `Strings.toString(IERC20(asset.token).balanceOf(address(this)))` |
| Max collateral rows | 4 (if `assets.length > 4` → show "+ N more") |
| Empty state | shown if `!isFixed` |
| Start price | `"$" + _formatPrice(startPrice, 8)` |
| Current price | `"$" + _formatPrice(getCurrentPrice(), 8)` |
| Price diff | `_formatPriceDiff(startPrice, getCurrentPrice())` |
| Chain name | `_chainName(block.chainid)` |
| Chain ID | `Strings.toString(block.chainid)` |
| Token ID | `Strings.toString(tokenId)` |
| Date / Block | omitted (unavailable in `view`) |

**Helper: `_formatPrice(uint256 raw, uint8 dec) internal pure returns (string memory)`**

Renders `raw` as a decimal string with `dec` fractional digits.  
Example: `raw=123456789, dec=8` → `"1.23456789"`.  
Algorithm: integer part = `raw / 10**dec`; fractional part = `raw % 10**dec`, left-padded with zeros to `dec` digits; strip trailing zeros.

**Helper: `_formatPriceDiff(uint256 start, uint256 current) internal pure returns (string memory)`**

Returns `"(+X.XX%)"` or `"(-X.XX%)"`. Returns `""` if `start == 0`.  
Compute: `absDiff = |current - start|`; `bps = absDiff * 10000 / start` (basis-points × 100 for 2 decimal places); format as `X.XX`.

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

### 2.10 JSON specification

```json
{
  "name": "Envelop Index",
  "description": "Envelop Index wNFT",
  "indexVersion": "<indexVersion>",
  "image": "data:image/svg+xml;base64,<Base64(_generateSVG(tokenId))>",
  "external_url": "https://app.envelop.is/token/<chainId>/<contractAddress>/<tokenId>",
  "attributes": [
    {"trait_type": "Start Price",   "value": <startPrice/1e8 decimal>,   "display_type": "number"},
    {"trait_type": "Current Price", "value": <currentPrice/1e8 decimal>, "display_type": "number"},
    {"trait_type": "Is Fixed",      "value": "<true|false>"},
    // per asset:
    {"trait_type": "<symbol> Amount",    "value": <amount/10^decimals decimal>, "display_type": "number"},
    {"trait_type": "<symbol> Price USD", "value": <oracle_price/1e8 decimal>,   "display_type": "number"}
  ],
  "collateral": [
    {
      "amount":          "<asset.amount as uint string>",
      "tokenId":         0,
      "assetType":       2,
      "contractAddress": "<asset.token lowercase hex>",
      "decimals":        <IERC20Metadata(asset.token).decimals()>,
      "price": {
        "base_asset":     "0x0000000000000000000000000000000000000348",
        "price":          "<IEnvelopOracle(oracle).getPriceInUSD(asset.token) as uint string, or 0>",
        "price_decimals": 8
      }
    }
    // one entry per asset in assets[]
  ],
  "locks": [
    {"param": <lock.param>, "lockType": <uint8(lock.lockType)>}
    // one entry per lock in _getWNFTV2Envelop721Storage().wnftData.locks
  ],
  "updatedAt": <block.timestamp>
}
```

Notes:
- If `!isFixed`: `collateral = []`, price attribute values = `0`
- Numeric values in JSON are unquoted decimal strings (e.g. `"value": 1.23`)
- String fields are JSON-escaped; contract addresses are lowercase hex
- All building via `string.concat()` / `abi.encodePacked()`

### 2.11 `name` / `symbol` / factory overrides

```solidity
function name()   public pure override returns (string memory) { return nftName; }
function symbol() public pure override returns (string memory) { return nftSymbol; }

// Same pattern as WNFTV2Index: clear name/symbol/tokenUri before proxy init
function createWNFTonFactory(InitParams memory _init) public override notDelegated returns (address)
function createWNFTonFactory2(InitParams memory _init) public override notDelegated returns (address)
```

---

## 3. `IAMMPriceAdapter` usage in the system

```
fixIndex(_assets, _oracle, _amm)
    │
    ├─► oracle.registerIndex(address(this), _assets, _amm)
    │       stores: _indexAssets[wNFT] = _assets
    │               indexAmm[wNFT]     = _amm        ← price source for this index
    │               isRegistered[wNFT] = true
    │
    └─► getCurrentPrice()
            └─► oracle.getIndexPrice(address(this))
                    └─► for each asset:
                          if indexAmm[wNFT] != 0:
                            IAMMPriceAdapter(amm).getTokenPriceUSD(token, amount)
                          else:
                            Chainlink via _getLatestPriceInUSD(token)
```

`Predicter` can also call `oracle.getIndexPrice(wNFT)` when resolving a prediction, getting the same price source as `getCurrentPrice()` — ensuring consistency between display, settlement, and prediction resolution.

---

## 4. `EnvelopOracle` extensions

**File:** `src/utils/EnvelopOracle.sol`  
**File:** `src/interfaces/IEnvelopOracle.sol`

### 4.1 New storage

```solidity
mapping(address wNFT => IEnvelopOracle.CompactAsset[]) internal _indexAssets;
mapping(address wNFT => bool)    public isRegistered;
mapping(address wNFT => address) public indexAmm;          // IAMMPriceAdapter or address(0)
mapping(address wNFT => address) public authorizedUpdater; // e.g. Predicter
```

### 4.2 New events

```solidity
event IndexRegistered(address indexed wNFT, IEnvelopOracle.CompactAsset[] assets, address amm);
event IndexPriceSet(address indexed wNFT, uint256 price, address indexed setter);
```

### 4.3 New functions

#### `registerIndex`

```solidity
function registerIndex(
    address _wNFT,
    IEnvelopOracle.CompactAsset[] calldata _assets,
    address _amm   // IAMMPriceAdapter address, or address(0)
) external
```

- Requires `msg.sender == _wNFT` — the index contract registers itself
- Copies `_assets` into `_indexAssets[_wNFT]`
- Sets `isRegistered[_wNFT] = true`, `indexAmm[_wNFT] = _amm`
- Emits `IndexRegistered(_wNFT, _assets, _amm)`

#### `setIndexUpdater`

```solidity
function setIndexUpdater(address _wNFT, address _updater) external
```

- Requires `msg.sender == _wNFT`
- Sets `authorizedUpdater[_wNFT] = _updater` (e.g. a deployed `Predicter` address)
- Allows `Predicter` to later call `setIndexPrice` after prediction resolution

#### `setIndexPrice`

```solidity
function setIndexPrice(address _wNFT, uint256 _price) external
```

- Requires `msg.sender == authorizedUpdater[_wNFT]` OR `msg.sender == owner()`
- Sets `overrided[_wNFT] = _price`
- Emits `IndexPriceSet(_wNFT, _price, msg.sender)`

### 4.4 Modified `getIndexPrice(address _v2Index)`

```
Priority order:
1. overrided[_v2Index] != 0
       → return overrided[_v2Index]               // manual/Predicter override

2. isRegistered[_v2Index]
       → uint256 total = 0
         address amm = indexAmm[_v2Index]
         for each asset in _indexAssets[_v2Index]:
           if amm != address(0):
             total += IAMMPriceAdapter(amm).getTokenPriceUSD(asset.token, asset.amount)
           else:
             uint8 dec = IERC20Metadata(asset.token).decimals()
             uint256 unitPrice = _getLatestPriceInUSD(asset.token)  // 1e8
             total += unitPrice * asset.amount / (10 ** dec)
         return total

3. else → return 0
```

`IAMMPriceAdapter.getTokenPriceUSD` already accounts for the `amount`, so its return value is added directly to `total` (no further scaling needed).

For the Chainlink path, `asset.amount` is in native token units, so division by `10**decimals` converts to human units before multiplying by the per-unit USD price (1e8).

### 4.5 Updated `IEnvelopOracle.sol`

Add to interface:

```solidity
function registerIndex(
    address _wNFT,
    CompactAsset[] calldata _assets,
    address _amm
) external;

function setIndexUpdater(address _wNFT, address _updater) external;

function setIndexPrice(address _wNFT, uint256 _price) external;

function isRegistered(address _wNFT) external view returns (bool);
function indexAmm(address _wNFT) external view returns (address);
```

---

## 5. Constraints summary

| # | Constraint |
|---|---|
| 1 | No HTTP/IPFS in `tokenURI` output except `external_url` field |
| 2 | `tokenURI` must be `view` — no state changes |
| 3 | SVG fully inline — no external fonts, images, scripts |
| 4 | `fixIndex` callable only once per wNFT (`isFixed` guard) |
| 5 | `registerIndex` callable only by the wNFT itself (`msg.sender == _wNFT`) |
| 6 | `setIndexPrice` callable only by `authorizedUpdater` or oracle owner |
| 7 | Existing `EnvelopOracle` tests must continue to pass |
| 8 | `pragma solidity ^0.8.28`, OpenZeppelin v5 |
| 9 | `IAMMPriceAdapter` returns values at 1e8 scale (same as Chainlink) |
