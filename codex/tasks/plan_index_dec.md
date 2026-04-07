# Implementation plan: WNFTV2SmartIndex & Oracle extensions

## Files

| Action | Path |
|--------|------|
| Create | `src/interfaces/IIndexAssets.sol` |
| Create | `src/interfaces/IAMMPriceAdapter.sol` |
| Modify | `src/interfaces/IEnvelopOracle.sol` |
| Modify | `src/utils/EnvelopOracle.sol` |
| Create | `src/impl/AbstractOnChainMetadata.sol` |
| Create | `src/impl/WNFTV2SmartIndex.sol` |
| Create | `test/WNFTV2SmartIndex_Test_a_01.sol` |

`WNFTV2Index.sol` — not modified.

---

## Step 1 — `src/interfaces/IIndexAssets.sol`

New file. Three-method callback interface for oracle → wNFT:
- `getIndexAssets() → CompactAsset[] memory`
- `getIndexAmm() → address`
- `getIndexBaseAsset() → address`

See full spec in `spec_index_dec.md §1.1`.

---

## Step 2 — `src/interfaces/IAMMPriceAdapter.sol`

New file. Single function:
```solidity
function getTokenPriceUSD(address token, uint96 amount, address baseAsset)
    external view returns (uint256 price, uint8 decimals);
```

Returns `(price, decimals)` — oracle normalizes to 1e8 during summation.
**Implementations MUST return TWAP ≥30 min — not spot price (Constraint #14).**

See full spec in `spec_index_dec.md §1.2`.

---

## Step 3 — `src/interfaces/IEnvelopOracle.sol`

Add to existing interface (do not remove anything):

```solidity
function registerIndex() external;
function deregisterIndex() external;
function setIndexUpdater(address _wNFT, address _updater) external;
function setIndexPrice(address _wNFT, uint256 _price) external;
function isRegistered(address _wNFT) external view returns (bool);
```

> All call-sites that declare a typed `IEnvelopOracle` variable must be recompiled against the updated interface. `EnvelopOracle.sol` must be redeployed on all chains.

---

## Step 4 — `src/utils/EnvelopOracle.sol`

### 4.1 New storage

```solidity
mapping(address => bool)    public isRegistered;
mapping(address => address) public authorizedUpdater;
```

No `CompactAsset[]` storage — assets fetched via `IIndexAssets` callback.

### 4.2 New imports

```solidity
import "../interfaces/IIndexAssets.sol";
import "../interfaces/IAMMPriceAdapter.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
```

### 4.3 Restore staleness check

In `_getLatestPriceInUSD` uncomment the disabled line (Constraint #13):

```solidity
require(_updatedAt + MAX_STALE >= block.timestamp, "Price is stale");
```

### 4.4 New events

```solidity
event EnvelopIndexRegistered(address indexed wNFT);
event EnvelopIndexDeregistered(address indexed wNFT);
event EnvelopIndexPriceSet(address indexed wNFT, uint256 price, address indexed setter);
```

### 4.5 Implement `registerIndex`

```solidity
function registerIndex() external {
    require(
        IERC165(msg.sender).supportsInterface(type(IIndexAssets).interfaceId),
        "Not IIndexAssets"
    );
    isRegistered[msg.sender] = true;
    emit EnvelopIndexRegistered(msg.sender);
}
```

### 4.6 Implement `deregisterIndex`

```solidity
function deregisterIndex() external {
    require(isRegistered[msg.sender], "Not registered");
    isRegistered[msg.sender] = false;
    emit EnvelopIndexDeregistered(msg.sender);
}
```

### 4.7 Implement `setIndexUpdater`

```solidity
function setIndexUpdater(address _wNFT, address _updater) external {
    require(msg.sender == _wNFT, "Only wNFT itself");
    authorizedUpdater[_wNFT] = _updater;
}
```

### 4.8 Implement `setIndexPrice`

```solidity
function setIndexPrice(address _wNFT, uint256 _price) external {
    require(
        msg.sender == authorizedUpdater[_wNFT] || msg.sender == owner(),
        "Not authorized"
    );
    overridedPrices[_wNFT] = _price;
    emit EnvelopIndexPriceSet(_wNFT, _price, msg.sender);
}
```

### 4.9 Modify `getIndexPrice(address _v2Index)`

Replace body:

```solidity
function getIndexPrice(address _v2Index) external view returns (uint256) {
    // 1. Manual/Predicter override
    if (overridedPrices[_v2Index] != 0) return overridedPrices[_v2Index];

    // 2. Auto-compute via callback
    if (isRegistered[_v2Index]) {
        IEnvelopOracle.CompactAsset[] memory assets = IIndexAssets(_v2Index).getIndexAssets();
        address amm       = IIndexAssets(_v2Index).getIndexAmm();
        address baseAsset = IIndexAssets(_v2Index).getIndexBaseAsset();
        uint256 total = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (amm != address(0)) {
                (uint256 price, uint8 dec) = IAMMPriceAdapter(amm)
                    .getTokenPriceUSD(assets[i].token, assets[i].amount, baseAsset);
                if (dec <= 8) {
                    total += price * 10 ** (8 - dec);
                } else {
                    total += price / 10 ** (dec - 8);
                }
            } else {
                uint8 tokenDec = IERC20Metadata(assets[i].token).decimals();
                uint256 unitPrice = _getLatestPriceInUSD(assets[i].token); // 1e8, staleness checked
                total += unitPrice * uint256(assets[i].amount) / (10 ** uint256(tokenDec));
            }
        }
        return total;
    }

    return 0;
}
```

---

## Step 5 — `src/impl/AbstractOnChainMetadata.sol`

New abstract contract. Contains all JSON/SVG generation logic. Concrete implementations provide data via virtual hooks; rendering never accesses storage directly.

### 5.1 Virtual hooks

Eleven `internal view virtual` hooks — see `spec_index_dec.md §2.1`. Note: no `_getMetadataIsFixed()` hook exists; fixedness is derived from `_getMetadataAssets().length > 0`.

### 5.2 Concrete methods

```solidity
function _encodeBase64JSON(uint256 tokenId) internal view returns (string memory)
function _generateJSON(uint256 tokenId) internal view returns (string memory)
function _generateSVG(uint256 tokenId) internal view returns (string memory)
function _formatPrice(uint256 raw, uint8 dec) internal pure returns (string memory)
function _formatPriceDiff(uint256 start, uint256 current) internal pure returns (string memory)
function _chainName(uint256 chainId) internal pure returns (string memory)
```

**All external calls inside `_generateSVG` and `_generateJSON`** (`symbol()`, `balanceOf()`, `decimals()`, oracle price) **MUST be wrapped in `try/catch`**; fall back to `"?"` / `0` on failure (Constraint #15).

### 5.3 `_formatPrice` / `_formatPriceDiff` / `_chainName`

```
_formatPrice(raw, dec):
  intPart  = raw / 10**dec
  fracPart = raw % 10**dec  → left-pad to dec digits → strip trailing zeros
  return concat(intPart, ".", fracPart)

_formatPriceDiff(start, current):
  if start == 0: return ""
  absDiff = |current - start|
  bps     = absDiff * 10000 / start
  sign    = current >= start ? "+" : "-"
  return concat("(", sign, bps/100, ".", pad2(bps%100), "%)")

_chainName: pure lookup table — see spec_index_dec.md §2.4
```

### 5.4 SVG / JSON rendering rules

- Gradient: `_getMetadataAssets().length == 0 || currentPrice >= startPrice` → green; `assets.length > 0 && currentPrice < startPrice` → red
- Empty state ("Waiting for assets..."): shown when `_getMetadataAssets().length == 0`
- Collateral rows: loop `min(MAX_SVG_COLLATERAL_ROWS, assets.length)`, Y = `100 + i * 26`
- "+ N more" if `assets.length > MAX_SVG_COLLATERAL_ROWS`
- JSON `collateral = []` when `assets.length == 0`
- JSON `"Is Fixed"` attribute value = `assets.length > 0`

Full SVG and JSON templates: `spec_index_dec.md §2.4–2.5`.

### 5.5 Imports

```solidity
import "../interfaces/IEnvelopOracle.sol";
import "../interfaces/IAMMPriceAdapter.sol";
import "../utils/LibET.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
```

---

## Step 6 — `src/impl/WNFTV2SmartIndex.sol`

Implement in this order:

### 6.1 Storage struct + accessor

```solidity
struct SmartIndexStorage {
    IEnvelopOracle.CompactAsset[] assets;  // slot 0
    address oracle;                         // slot 1 (20 bytes)
    uint40  createdAt;                      // slot 1 (+5 bytes)
    // "is fixed" ≡ assets.length > 0 — no bool field
    address baseAsset;                      // slot 2 (20 bytes)
    uint96  startPrice;                     // slot 2 (+12 bytes)
}
// AMM_ADAPTER is immutable (constructor arg) — not stored here
```

EIP-7201 namespaced slot: `keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTV2SmartIndex")) - 1)) & ~bytes32(uint256(0xff))`.

### 6.2 Constructor & immutables

```solidity
address public immutable AMM_ADAPTER;

constructor(address _defaultFactory, address _ammAdapter)
    WNFTV2Envelop721(_defaultFactory)
{
    AMM_ADAPTER = _ammAdapter;
}
```

### 6.3 `fixIndex`

Parameters: `(CompactAsset[] calldata _assets, address _oracle, address _baseAsset)`

Execution order:
1. `require($.assets.length == 0, "Already fixed")` — `assets.length > 0` is the "fixed" sentinel
2. `require(_assets.length > 0 && _assets.length <= MAX_ASSETS)`
3. Copy `_assets` into `$.assets`
4. Store `$.oracle`, `$.baseAsset`
5. `$.createdAt = uint40(block.timestamp)`
6. `IEnvelopOracle(_oracle).registerIndex()` — registers `msg.sender` in oracle (ERC-165 validated)
7. `$.startPrice = SafeCast.toUint96(IEnvelopOracle(_oracle).getIndexPrice(address(this)))` — **after** registration so oracle uses AMM/Chainlink via callback
8. Emit `EnvelopIndexFixed`

Modifier: `onlyWnftOwner` (inherited from `WNFTV2Envelop721` — checks `ownerOf(TOKEN_ID) == msg.sender`).

### 6.4 `IIndexAssets` implementation

```solidity
function getIndexAssets()    external view returns (CompactAsset[] memory) { return $.assets; }
function getIndexAmm()       external view returns (address) { return AMM_ADAPTER; } // immutable
function getIndexBaseAsset() external view returns (address) { return $.baseAsset; }
```

### 6.5 View functions

```solidity
function getCurrentPrice() public view returns (uint256) {
    SmartIndexStorage storage $ = _getSmartIndexStorage();
    if ($.assets.length > 0 && $.oracle != address(0))
        return IEnvelopOracle($.oracle).getIndexPrice(address(this));
    return 0;
}

function getIndexRecord() external view returns (SmartIndexStorage memory)
```

### 6.6 `setIndexUpdater`

```solidity
function setIndexUpdater(address _oracle, address _updater) external onlyWnftOwner {
    IEnvelopOracle(_oracle).setIndexUpdater(address(this), _updater);
}
```

### 6.7 `_beforeUnwrap` hook (oracle deregistration)

```solidity
function _beforeUnwrap(/* same signature as base */) internal override {
    SmartIndexStorage storage $ = _getSmartIndexStorage();
    if ($.assets.length > 0 && $.oracle != address(0)) {
        try IEnvelopOracle($.oracle).deregisterIndex() {} catch {}
    }
    super._beforeUnwrap(/* ... */);
}
```

Clears oracle registration before collateral release. `try/catch` ensures a failing oracle never blocks unwrapping (Constraint #17).

### 6.8 `AbstractOnChainMetadata` virtual hook implementations

Ten hooks — see `spec_index_dec.md §3.9`. No `_getMetadataIsFixed()` hook (removed; fixedness derived from `assets.length`).

### 6.9 `tokenURI` + `name` / `symbol` / `supportsInterface` / factory overrides

```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return _encodeBase64JSON(tokenId);
}

function name()   public pure override returns (string memory) { return nftName; }
function symbol() public pure override returns (string memory) { return nftSymbol; }

function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
    return interfaceId == type(IIndexAssets).interfaceId
        || super.supportsInterface(interfaceId);
}

// factory overrides: clear nftName/nftSymbol/tokenUri before super (same pattern as WNFTV2Index)
```

### 6.10 Required imports

```solidity
import "./WNFTV2Envelop721.sol";
import "./AbstractOnChainMetadata.sol";
import "../interfaces/IEnvelopOracle.sol";
import "../interfaces/IIndexAssets.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
```

---

## Step 7 — Tests

### `test/WNFTV2SmartIndex_Test_a_01.sol`

Setup:
- Deploy `MockERC20` tokens (from `src/mock/`)
- Deploy `MockFeedRegistry` (from `src/mock/`)
- Deploy `EnvelopWNFTFactory` + `WNFTV2SmartIndex` implementation
- Create proxy via `factory.createWNFT()`

Test cases:
1. `test_fixIndex_stores_data` — call `fixIndex`, assert `getIndexRecord()` fields match
2. `test_fixIndex_reverts_twice` — second call reverts `"Already fixed"`
3. `test_fixIndex_enforces_max_assets` — array > `MAX_ASSETS` reverts
4. `test_fixIndex_registers_in_oracle` — assert `oracle.isRegistered(wNFT) == true`
5. `test_fixIndex_with_amm` — pass mock AMM adapter, assert `getIndexAmm() == AMM_ADAPTER`
6. `test_fixIndex_startPrice_uses_amm` — mock AMM returns different price than Chainlink, assert `startPrice` matches AMM
7. `test_tokenURI_prefix` — `tokenURI(1)` starts with `"data:application/json;base64,"`
8. `test_tokenURI_json_valid` — base64 decode + `vm.parseJson`, check `name`, `indexVersion`, `updatedAt`
9. `test_tokenURI_image_svg` — check `image` field starts with `"data:image/svg+xml;base64,"`
10. `test_tokenURI_collateral_populated` — collateral array length matches `assets`
11. `test_svg_green_when_price_up` — mock oracle returns higher current price → no `paint_linear_1_red` in SVG
12. `test_svg_red_when_price_down` — mock oracle returns lower current price → contains `paint_linear_1_red`
13. `test_setIndexPrice_by_updater` — authorized updater can set override price
14. `test_setIndexPrice_reverts_unauthorized` — random address reverts
15. `test_deregister_on_unwrap` — after `unwrap()`, `oracle.isRegistered(wNFT) == false`
16. `test_tokenURI_bad_token_no_revert` — add a mock token whose `symbol()` reverts; `tokenURI` must still return valid JSON
17. `test_svg_pending_state` — before `fixIndex`, SVG contains "Waiting for assets..."

### Oracle regression

```bash
forge test --match-contract EnvelopOracle_Test -vvv  # existing tests must pass
```

---

## Reuse checklist

| Item | Location |
|------|----------|
| `IEnvelopOracle.CompactAsset` | `src/interfaces/IEnvelopOracle.sol` |
| `ET.Lock` | `src/utils/LibET.sol` |
| `Strings` | already imported in `WNFTV2Index.sol` |
| `Base64` | `@openzeppelin/contracts/utils/Base64.sol` |
| `SafeCast` | `@openzeppelin/contracts/utils/math/SafeCast.sol` |
| `IERC20Metadata` | `@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` |
| `IERC165` | `@openzeppelin/contracts/utils/introspection/IERC165.sol` |
| `onlyWnftOwner` | `WNFTV2Envelop721` — checks `ownerOf(TOKEN_ID) == msg.sender` |
| `_getWNFTV2Envelop721Storage()` | `WNFTV2Envelop721` — for `wnftData.locks` |
| `MockERC20`, `MockFeedRegistry` | `src/mock/` |
| `_getLatestPriceInUSD` | reused in oracle's `getIndexPrice(address)` Chainlink path |
| `overridedPrices` | existing mapping in `EnvelopOracle` — reused by `setIndexPrice` |

---

## Build & test

```bash
forge build

# New implementation tests
forge test --match-contract WNFTV2SmartIndex_Test -vvv

# Oracle regression
forge test --match-contract EnvelopOracle_Test -vvv

# Full suite
forge test -vvv
```
