# Implementation plan: WNFTV2SmartIndex & Oracle extensions

## Files

| Action | Path |
|--------|------|
| Create | `src/interfaces/IIndexAssets.sol` |
| Create | `src/interfaces/IAMMPriceAdapter.sol` |
| Modify | `src/interfaces/IEnvelopOracle.sol` |
| Modify | `src/utils/EnvelopOracle.sol` |
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

See full spec in `spec_index_dec.md §1.2`.

---

## Step 3 — `src/interfaces/IEnvelopOracle.sol`

Add to existing interface (do not remove anything):

```solidity
function registerIndex() external;
function setIndexUpdater(address _wNFT, address _updater) external;
function setIndexPrice(address _wNFT, uint256 _price) external;
function isRegistered(address _wNFT) external view returns (bool);
```

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
```

### 4.3 Implement `registerIndex`

```solidity
function registerIndex() external {
    isRegistered[msg.sender] = true;
    emit EnvelopIndexRegistered(msg.sender);
}
```

### 4.4 Implement `setIndexUpdater`

```solidity
function setIndexUpdater(address _wNFT, address _updater) external {
    require(msg.sender == _wNFT, "Only wNFT itself");
    authorizedUpdater[_wNFT] = _updater;
}
```

### 4.5 Implement `setIndexPrice`

```solidity
function setIndexPrice(address _wNFT, uint256 _price) external {
    require(
        msg.sender == authorizedUpdater[_wNFT] || msg.sender == owner(),
        "Not authorized"
    );
    overrided[_wNFT] = _price;
    emit EnvelopIndexPriceSet(_wNFT, _price, msg.sender);
}
```

### 4.6 Modify `getIndexPrice(address _v2Index)`

Replace body:

```solidity
function getIndexPrice(address _v2Index) external view returns (uint256) {
    // 1. Manual/Predicter override
    if (overrided[_v2Index] != 0) return overrided[_v2Index];

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
                uint256 unitPrice = _getLatestPriceInUSD(assets[i].token); // 1e8
                total += unitPrice * uint256(assets[i].amount) / (10 ** uint256(tokenDec));
            }
        }
        return total;
    }

    return 0;
}
```

### 4.7 New events

```solidity
event EnvelopIndexRegistered(address indexed wNFT);
event EnvelopIndexPriceSet(address indexed wNFT, uint256 price, address indexed setter);
```

---

## Step 5 — `src/impl/WNFTV2SmartIndex.sol`

Implement in this order:

### 5.1 Storage struct + accessor

Namespaced slot, `SmartIndexStorage` with 4 storage slots.
See `spec_index_dec.md §2.2`.

### 5.2 `fixIndex`

Parameters: `(CompactAsset[] calldata _assets, address _oracle, address _amm, address _baseAsset)`

Execution order:
1. `require(!$.isFixed, "Already fixed")`
2. `require(_assets.length > 0 && _assets.length <= MAX_ASSETS)`
3. Copy `_assets` into `$.assets`
4. Store `$.oracle`, `$.amm`, `$.baseAsset`
5. `$.createdAt = uint40(block.timestamp)`, `$.isFixed = true`
6. `IEnvelopOracle(_oracle).registerIndex()` — registers `msg.sender` in oracle
7. `$.startPrice = SafeCast.toUint96(IEnvelopOracle(_oracle).getIndexPrice(address(this)))` — **after** registration so oracle uses AMM/Chainlink via callback
8. Emit `EnvelopIndexFixed`

### 5.3 `IIndexAssets` implementation

Three view functions returning from `SmartIndexStorage`:
- `getIndexAssets()` → `$.assets`
- `getIndexAmm()` → `$.amm`
- `getIndexBaseAsset()` → `$.baseAsset`

### 5.4 Price helpers

**`_formatPrice(uint256 raw, uint8 dec)`**
```
intPart  = raw / 10**dec
fracPart = raw % 10**dec  → left-pad to `dec` digits → strip trailing zeros
return concat(intPart, ".", fracPart)
```

**`_formatPriceDiff(uint256 start, uint256 current)`**
```
if start == 0: return ""
absDiff = current >= start ? current - start : start - current
bps     = absDiff * 10000 / start
sign    = current >= start ? "+" : "-"
return concat("(", sign, bps/100, ".", pad2(bps%100), "%)")
```

**`_chainName(uint256 chainId)`** — pure lookup, see `spec_index_dec.md §2.9`.

### 5.5 `_generateSVG`

Translate `codex/tasks/default.svg` Jinja2 → Solidity `string.concat()`.

Key points:
- Gradient: `isFixed && getCurrentPrice() < $.startPrice` → red, else green
- All `<defs>` gradients inlined (green + red + info-box gradients)
- Logo paths: verbatim from SVG template
- Animated border: `"Index \xE2\x80\xA2 " + address hex`
- Collateral rows: loop `min(MAX_SVG_COLLATERAL_ROWS, assets.length)`, Y = `100 + i * 26`
- "+ N more" if `assets.length > MAX_SVG_COLLATERAL_ROWS`
- If `!isFixed`: "Waiting for assets..." placeholder
- Price section: rendered only if `isFixed`
- Token info: always rendered (chain, chainId, tokenId)

### 5.6 `_generateJSON`

Build via `string.concat()`. Sub-sections:
- header: name, description, indexVersion, image (embed SVG base64), external_url
- attributes: start/current price, isFixed, per-asset symbol+amount+price
- collateral: per-asset — `tokenId=0`, `assetType=2`, decimals, price with `base_asset` and `price_decimals`
- locks: from `_getWNFTV2Envelop721Storage().wnftData.locks`
- updatedAt: `block.timestamp`

For `price.price` per asset: `IEnvelopOracle($.oracle).getPriceInUSD(asset.token)` if oracle set, else `"0"`.
For `price.price_decimals`: `8` for Chainlink path; from `IAMMPriceAdapter` return for AMM path.

### 5.7 `tokenURI` + factory overrides

```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return _encodeBase64JSON(tokenId);
}

function createWNFTonFactory(InitParams memory _init) public override notDelegated returns (address) {
    _init.nftName = ""; _init.nftSymbol = ""; _init.tokenUri = "";
    return super.createWNFTonFactory(_init);
}
// same for createWNFTonFactory2
```

---

## Step 6 — Tests

### `test/WNFTV2SmartIndex_Test_a_01.sol`

Setup:
- Deploy `MockERC20` tokens (from `src/mock/`)
- Deploy `MockOracle` or `MockFeedRegistry` (from `src/mock/`)
- Deploy `EnvelopWNFTFactory` + `WNFTV2SmartIndex` implementation
- Create proxy via `factory.createWNFT()`

Test cases:
1. `test_fixIndex_stores_data` — call `fixIndex`, assert `getIndexRecord()` fields match
2. `test_fixIndex_reverts_twice` — second call reverts `"Already fixed"`
3. `test_fixIndex_enforces_max_assets` — array > `MAX_ASSETS` reverts
4. `test_fixIndex_registers_in_oracle` — assert `oracle.isRegistered(wNFT) == true`
5. `test_fixIndex_with_amm` — pass mock AMM adapter, assert `getIndexAmm() == mockAmm`
6. `test_fixIndex_startPrice_uses_amm` — mock AMM returns different price than Chainlink, assert startPrice matches AMM
7. `test_tokenURI_prefix` — `tokenURI(1)` starts with `"data:application/json;base64,"`
8. `test_tokenURI_json_valid` — base64 decode + `vm.parseJson`, check `name`, `indexVersion`, `updatedAt`
9. `test_tokenURI_image_svg` — check `image` field starts with `"data:image/svg+xml;base64,"`
10. `test_tokenURI_collateral_populated` — collateral array length matches assets
11. `test_svg_green_when_price_up` — mock oracle returns higher current price → no `paint_linear_1_red` in SVG
12. `test_svg_red_when_price_down` — mock oracle returns lower current price → contains `paint_linear_1_red`
13. `test_setIndexPrice_by_updater` — authorized updater can set override price
14. `test_setIndexPrice_reverts_unauthorized` — random address reverts

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
| `Base64` | `@openzeppelin/contracts/utils/Base64.sol` (new import) |
| `SafeCast` | `@openzeppelin/contracts/utils/math/SafeCast.sol` (new import) |
| `IERC20Metadata` | `@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` |
| `onlyWnftOwner` | `Singleton721` |
| `_getWNFTV2Envelop721Storage()` | `WNFTV2Envelop721` — for `wnftData.locks` |
| `MockERC20`, `MockOracle`, `MockFeedRegistry` | `src/mock/` |
| `_getLatestPriceInUSD` | reused in oracle's `getIndexPrice(address)` Chainlink path |

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
