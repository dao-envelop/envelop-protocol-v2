# Specification: WNFTV2SmartIndex & EnvelopOracle extensions

## Overview

1. New wNFT implementation `WNFTV2SmartIndex` — on-chain `tokenURI`, index asset registry inside the wNFT proxy
2. New interface `IIndexAssets` — callback for oracle to fetch assets from wNFT
3. New interface `IAMMPriceAdapter` — abstraction over AMM price sources
4. Extensions to `EnvelopOracle` — auto-compute index price via callback, AMM support, ACL for Predicter

Does **not** modify `WNFTV2Index.sol`.

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
     */
    function getTokenPriceUSD(address token, uint96 amount, address baseAsset)
        external view returns (uint256 price, uint8 decimals);
}
```

---

## 2. `WNFTV2SmartIndex`

**File:** `src/impl/WNFTV2SmartIndex.sol`
**Inherits:** `WNFTV2Envelop721`, `IIndexAssets`
**Pragma:** `^0.8.28`

### 2.1 Constructor & immutables

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

### 2.2 Constants

```solidity
string  public constant nftName      = "Envelop wNFT V2 Smart Index";
string  public constant nftSymbol    = "ENVELOPV2";
string  public constant indexVersion = "2.1.0";
uint256 public constant MAX_ASSETS   = 100;  // portfolio cap (same as Predicter)
uint256 internal constant MAX_SVG_COLLATERAL_ROWS = 4;
```

### 2.2 Namespaced storage

```solidity
bytes32 private constant SMART_INDEX_STORAGE_LOCATION =
    keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTV2SmartIndex")) - 1))
    & ~bytes32(uint256(0xff));

struct SmartIndexStorage {
    // slot 0: dynamic array (always full slot)
    IEnvelopOracle.CompactAsset[] assets;
    // slot 1: oracle(20) + createdAt(5) + isFixed(1) = 26 bytes (6 free)
    address oracle;
    uint40  createdAt;
    bool    isFixed;
    // slot 2: baseAsset(20) + startPrice(12) = 32 bytes exact
    address baseAsset;   // base token for AMM pricing (e.g. USDC, WETH)
                         // address(0) = USD denomination (Chainlink path)
    uint96  startPrice;  // 1e8 decimals; max ~7.9e20 USD
}
// 3 slots total. AMM adapter is immutable AMM_ADAPTER, not in storage.
// CompactAsset=(address,uint96) = 32 bytes per element.

function _getSmartIndexStorage() private pure returns (SmartIndexStorage storage $) {
    assembly { $.slot := SMART_INDEX_STORAGE_LOCATION }
}
```

### 2.3 Events

```solidity
event EnvelopIndexFixed(
    address indexed creator,
    uint96  startPrice,
    IEnvelopOracle.CompactAsset[] assets
);
```

### 2.4 Function: `fixIndex`

```solidity
function fixIndex(
    IEnvelopOracle.CompactAsset[] calldata _assets,
    address _oracle,
    address _baseAsset
) external onlyWnftOwner
```

Execution order:
1. `require(!$.isFixed, "Already fixed")`
2. `require(_assets.length > 0 && _assets.length <= MAX_ASSETS)`
3. Copy `_assets` into `$.assets`
4. `$.oracle = _oracle`, `$.baseAsset = _baseAsset`
5. `$.createdAt = uint40(block.timestamp)`, `$.isFixed = true`
6. `IEnvelopOracle(_oracle).registerIndex()` — oracle registers `msg.sender`
7. `$.startPrice = SafeCast.toUint96(IEnvelopOracle(_oracle).getIndexPrice(address(this)))` — **AFTER** registration so oracle uses correct price source (AMM or Chainlink via callback)
8. Emit `EnvelopIndexFixed(msg.sender, $.startPrice, _assets)`

### 2.5 View functions

```solidity
function getCurrentPrice() public view returns (uint256)
```
- If `isFixed && oracle != address(0)`: return `IEnvelopOracle(oracle).getIndexPrice(address(this))`
- Else: return `0`

```solidity
function getIndexRecord() external view returns (SmartIndexStorage memory)
```

### 2.6 `IIndexAssets` implementation

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

### 2.7 `tokenURI` and helpers

```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory)
```
Returns `_encodeBase64JSON(tokenId)`.

```solidity
function _encodeBase64JSON(uint256 tokenId) internal view returns (string memory)
```
Returns `string.concat("data:application/json;base64,", Base64.encode(bytes(_generateJSON(tokenId))))`.

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
import "../interfaces/IIndexAssets.sol";
import "../interfaces/IAMMPriceAdapter.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
```

### 2.9 SVG specification

**Canvas:** 300x500, `viewBox="0 0 300 500"`, `rx="20"`, no external resources.

**Gradient selection:**

| Condition | Gradient IDs |
|---|---|
| `!isFixed` OR `getCurrentPrice() >= startPrice` | `paint_linear_1`, `paint_linear_2` (green) |
| `isFixed && getCurrentPrice() < startPrice` | `paint_linear_1_red`, `paint_linear_2_red` (red) |

Both gradient definitions inlined in `<defs>`. Yellow variant reserved for future.

**Template variable mapping:**

| SVG element | Solidity expression |
|---|---|
| Animated border text | `"Index \u2022 " + Strings.toHexString(uint160(address(this)), 20)` |
| Title | `symbol()` |
| Collateral rows | loop `i` in `0..min(MAX_SVG_COLLATERAL_ROWS, assets.length)`: symbol via `IERC20Metadata(asset.token).symbol()`, balance via `IERC20(asset.token).balanceOf(address(this))` |
| Y-coordinate per row | `100 + i * 26` |
| "+ N more" row | if `assets.length > MAX_SVG_COLLATERAL_ROWS`: N = `assets.length - MAX_SVG_COLLATERAL_ROWS` |
| Empty state | shown if `!isFixed`: "Waiting for assets..." |
| Start price | `"$" + _formatPrice(startPrice, 8)` |
| Current price | `"$" + _formatPrice(getCurrentPrice(), 8)` |
| Price diff | `_formatPriceDiff(startPrice, getCurrentPrice())` |
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

### 2.10 JSON specification

```json
{
  "name": "Envelop Index",
  "description": "Envelop Index wNFT",
  "indexVersion": "<indexVersion>",
  "image": "data:image/svg+xml;base64,<Base64(_generateSVG(tokenId))>",
  "external_url": "https://app.envelop.is/token/<chainId>/<contractAddress>/<tokenId>",
  "attributes": [
    {"trait_type": "Start Price",   "value": <startPrice/1e8>,   "display_type": "number"},
    {"trait_type": "Current Price", "value": <currentPrice/1e8>, "display_type": "number"},
    {"trait_type": "Is Fixed",      "value": "<true|false>"},
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
        "base_asset":     "<SmartIndexStorage.baseAsset; address(0) = USD>",
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
- `CompactAsset` is ERC20-only → `tokenId` always `0`, `assetType` always `2`
- If `!isFixed`: `collateral = []`, price attribute values = `0`
- `wnftData.locks` accessed via `_getWNFTV2Envelop721Storage().wnftData.locks`
- `price_decimals`: `8` for Chainlink path; value from `IAMMPriceAdapter` return for AMM path
- `base_asset`: from `SmartIndexStorage.baseAsset`

### 2.11 `name` / `symbol` / factory overrides

```solidity
function name()   public pure override returns (string memory) { return nftName; }
function symbol() public pure override returns (string memory) { return nftSymbol; }
```

Factory overrides clear `nftName`/`nftSymbol`/`tokenUri` before calling `super` (same pattern as `WNFTV2Index`).

---

## 3. Price source flow

```
fixIndex(_assets, _oracle, _baseAsset)
    │
    ├─► store assets, oracle, baseAsset in SmartIndexStorage (amm is immutable)
    ├─► isFixed = true
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

## 4. `EnvelopOracle` extensions

**File:** `src/utils/EnvelopOracle.sol`
**File:** `src/interfaces/IEnvelopOracle.sol`

### 4.1 New storage

```solidity
mapping(address wNFT => bool)    public isRegistered;
mapping(address wNFT => address) public authorizedUpdater; // e.g. Predicter
```

No `CompactAsset[]` storage — assets fetched via `IIndexAssets` callback.

### 4.2 New events

```solidity
event EnvelopIndexRegistered(address indexed wNFT);
event EnvelopIndexPriceSet(address indexed wNFT, uint256 price, address indexed setter);
```

### 4.3 New functions

#### `registerIndex`

```solidity
function registerIndex() external
```
- Sets `isRegistered[msg.sender] = true`
- Emits `EnvelopIndexRegistered(msg.sender)`

No parameters — the wNFT calls this, oracle registers `msg.sender`.

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
- Sets `overrided[_wNFT] = _price`
- Emits `EnvelopIndexPriceSet(_wNFT, _price, msg.sender)`

### 4.4 Modified `getIndexPrice(address _v2Index)`

```
Priority order:
1. overrided[_v2Index] != 0
       → return overrided[_v2Index]                   // manual/Predicter override

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
             total += unitPrice * uint256(asset.amount) / (10 ** uint256(tokenDec))
         return total  // always 1e8 scale

3. else → return 0
```

New imports for `EnvelopOracle.sol`:
```solidity
import "../interfaces/IIndexAssets.sol";
import "../interfaces/IAMMPriceAdapter.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
```

### 4.5 Updated `IEnvelopOracle.sol`

Add to interface:

```solidity
function registerIndex() external;
function setIndexUpdater(address _wNFT, address _updater) external;
function setIndexPrice(address _wNFT, uint256 _price) external;
function isRegistered(address _wNFT) external view returns (bool);
```

---

## 5. Constraints summary

| # | Constraint |
|---|---|
| 1 | No HTTP/IPFS in `tokenURI` output except `external_url` |
| 2 | `tokenURI` must be `view` — no state changes |
| 3 | SVG fully inline — no external resources |
| 4 | `fixIndex` callable once per wNFT (`isFixed` guard) |
| 5 | `assets.length <= MAX_ASSETS` enforced in `fixIndex` |
| 6 | SVG displays at most `MAX_SVG_COLLATERAL_ROWS` collateral rows |
| 7 | `registerIndex()` uses `msg.sender` — no parameter |
| 8 | `startPrice` stored as `uint96` via `SafeCast.toUint96` |
| 9 | AMM adapter returns `(price, decimals)` — oracle normalizes to 1e8 |
| 10 | `CompactAsset` is ERC20-only → collateral `tokenId=0`, `assetType=2` |
| 11 | Existing `EnvelopOracle` tests must continue to pass |
| 12 | `pragma solidity ^0.8.28`, OpenZeppelin v5 |
