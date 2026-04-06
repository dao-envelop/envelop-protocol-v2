# Implementation plan: WNFTV2SmartIndex & Oracle extensions

## Files

| Action | Path |
|--------|------|
| Create | `src/interfaces/IAMMPriceAdapter.sol` |
| Create | `src/impl/WNFTV2SmartIndex.sol` |
| Modify | `src/interfaces/IEnvelopOracle.sol` |
| Modify | `src/utils/EnvelopOracle.sol` |
| Create | `test/WNFTV2SmartIndex_Test_a_01.sol` |
| Create | `test/EnvelopOracle_Test_a_ext.sol` (oracle extension tests) |

`WNFTV2Index.sol` — not modified.

---

## Step 1 — `src/interfaces/IAMMPriceAdapter.sol`

New file, ~15 lines. Interface with one function:

```solidity
function getTokenPriceUSD(address token, uint96 amount) external view returns (uint256);
```

See full spec in `spec_index_dec.md §1`.

---

## Step 2 — `src/interfaces/IEnvelopOracle.sol`

Add to existing interface (do not remove anything):

```solidity
function registerIndex(address _wNFT, CompactAsset[] calldata _assets, address _amm) external;
function setIndexUpdater(address _wNFT, address _updater) external;
function setIndexPrice(address _wNFT, uint256 _price) external;
function isRegistered(address _wNFT) external view returns (bool);
function indexAmm(address _wNFT) external view returns (address);
```

---

## Step 3 — `src/utils/EnvelopOracle.sol`

### 3.1 New storage variables

```solidity
mapping(address => IEnvelopOracle.CompactAsset[]) internal _indexAssets;
mapping(address => bool)    public isRegistered;
mapping(address => address) public indexAmm;
mapping(address => address) public authorizedUpdater;
```

Add after existing `mapping(address object => uint256 overrided)`.

### 3.2 New events

```solidity
event IndexRegistered(address indexed wNFT, IEnvelopOracle.CompactAsset[] assets, address amm);
event IndexPriceSet(address indexed wNFT, uint256 price, address indexed setter);
```

### 3.3 Implement `registerIndex`

```solidity
function registerIndex(
    address _wNFT,
    IEnvelopOracle.CompactAsset[] calldata _assets,
    address _amm
) external {
    require(msg.sender == _wNFT, "Only wNFT itself");
    // clear and copy
    delete _indexAssets[_wNFT];
    for (uint i = 0; i < _assets.length; i++) {
        _indexAssets[_wNFT].push(_assets[i]);
    }
    isRegistered[_wNFT] = true;
    indexAmm[_wNFT] = _amm;
    emit IndexRegistered(_wNFT, _assets, _amm);
}
```

### 3.4 Implement `setIndexUpdater`

```solidity
function setIndexUpdater(address _wNFT, address _updater) external {
    require(msg.sender == _wNFT, "Only wNFT itself");
    authorizedUpdater[_wNFT] = _updater;
}
```

### 3.5 Implement `setIndexPrice`

```solidity
function setIndexPrice(address _wNFT, uint256 _price) external {
    require(
        msg.sender == authorizedUpdater[_wNFT] || msg.sender == owner(),
        "Not authorized"
    );
    overrided[_wNFT] = _price;
    emit IndexPriceSet(_wNFT, _price, msg.sender);
}
```

Note: existing `overrideIndexPrice(address, uint256)` (owner-only) can remain as a separate convenience function pointing to the same storage slot.

### 3.6 Modify `getIndexPrice(address _v2Index)`

Replace body with:

```solidity
function getIndexPrice(address _v2Index) external view returns (uint256) {
    // 1. Manual override takes precedence
    if (overrided[_v2Index] != 0) return overrided[_v2Index];

    // 2. Auto-compute from registered portfolio
    if (isRegistered[_v2Index]) {
        IEnvelopOracle.CompactAsset[] storage assets = _indexAssets[_v2Index];
        address amm = indexAmm[_v2Index];
        uint256 total = 0;
        for (uint i = 0; i < assets.length; i++) {
            if (amm != address(0)) {
                total += IAMMPriceAdapter(amm).getTokenPriceUSD(assets[i].token, assets[i].amount);
            } else {
                uint8 dec = IERC20Metadata(assets[i].token).decimals();
                uint256 unitPrice = _getLatestPriceInUSD(assets[i].token); // 1e8
                total += unitPrice * uint256(assets[i].amount) / (10 ** uint256(dec));
            }
        }
        return total;
    }

    return 0;
}
```

Add import: `import "../interfaces/IAMMPriceAdapter.sol";` and `import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";`

---

## Step 4 — `src/impl/WNFTV2SmartIndex.sol`

Implement in this order:

### 4.1 Storage struct + accessor

```solidity
bytes32 private constant SMART_INDEX_STORAGE_LOCATION =
    keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTV2SmartIndex")) - 1))
    & ~bytes32(uint256(0xff));
```

### 4.2 `fixIndex`

Parameters: `(CompactAsset[] calldata _assets, address _oracle, address _amm)`

Steps:
1. `require(!$.isFixed, "Already fixed")`
2. `require(_assets.length > 0)`
3. Copy `_assets` into `$.assets`
4. `$.startPrice = IEnvelopOracle(_oracle).getIndexPrice(_assets)` — use existing overload
5. Store oracle + amm, set `isFixed = true`, `createdAt = block.timestamp`
6. `IEnvelopOracle(_oracle).registerIndex(address(this), _assets, _amm)` — this call is made FROM the wNFT, so `msg.sender == address(this)` satisfies the oracle check
7. Emit `IndexFixed`

### 4.3 Price helpers

**`_formatPrice(uint256 raw, uint8 dec)`**

```
intPart  = raw / 10**dec
fracPart = raw % 10**dec  → left-pad to `dec` digits → strip trailing zeros
if fracPart == 0: return Strings.toString(intPart)
else: return concat(intPart, ".", fracPart_string)
```

**`_formatPriceDiff(uint256 start, uint256 current)`**

```
if start == 0: return ""
absDiff = current >= start ? current - start : start - current
bps     = absDiff * 10000 / start   // e.g. 150 = 1.50%
sign    = current >= start ? "+" : "-"
return concat("(", sign, bps/100, ".", pad2(bps%100), "%)")
```

**`_chainName(uint256 chainId)`** — pure lookup table, see spec §2.9.

### 4.4 `_generateSVG`

Translate `codex/tasks/default.svg` Jinja2 template to Solidity `string.concat()` calls.

Key points:
- Determine gradient IDs: `isFixed && getCurrentPrice() < $.startPrice` → `paint_linear_1_red`, else `paint_linear_1`
- Inline ALL gradient `<defs>` from the template (green + red variants, plus the 5 linear gradients for info boxes `paint2..paint6_linear_5869_12693`)
- Envelop logo paths: copy verbatim from SVG template (both `logo-bg` opacity group and `logo` group)
- Animated border text: `string.concat("Index \xE2\x80\xA2 ", Strings.toHexString(uint160(address(this)), 20))`
- Collateral rows: loop up to `min(4, assets.length)`, call `IERC20Metadata.symbol()` and `IERC20.balanceOf(address(this))` per asset
- If `assets.length > 4`: add "+ N more" row
- If `!isFixed`: render "Waiting for assets..." placeholder
- Price section: only rendered if `isFixed`
- Token info section (chain, chain ID, token ID): always rendered

### 4.5 `_generateJSON`

Build with `string.concat`. Sub-sections:

```
header:     name, description, indexVersion, image (embed _generateSVG output base64), external_url
attributes: loop assets[] for per-asset attributes + start/current price + isFixed
collateral: loop assets[] — for each: amount, tokenId=0, assetType=2, contractAddress, decimals, price object
locks:      loop _getWNFTV2Envelop721Storage().wnftData.locks
updatedAt:  block.timestamp
```

For `price.price` per asset: call `IEnvelopOracle($.oracle).getPriceInUSD(asset.token)` if `$.oracle != address(0)`, else `"0"`. This gets Chainlink price for the asset regardless of whether the index uses AMM for total pricing — it's informational metadata.

### 4.6 `tokenURI` + factory overrides

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

## Step 5 — Tests

### `test/WNFTV2SmartIndex_Test_a_01.sol`

Setup:
- Deploy `MockERC20` tokens (already in `src/mock/`)
- Deploy `MockOracle` or `MockFeedRegistry` (already in `src/mock/`)
- Deploy `EnvelopWNFTFactory` + `WNFTV2SmartIndex` implementation
- Create proxy via `factory.createWNFT()`

Test cases:
1. `test_fixIndex_stores_data` — call `fixIndex`, assert `getIndexRecord()` fields
2. `test_fixIndex_reverts_twice` — second `fixIndex` call reverts `"Already fixed"`
3. `test_fixIndex_registers_in_oracle` — assert `oracle.isRegistered(wNFT) == true`
4. `test_fixIndex_with_amm` — pass a mock AMM adapter, assert `oracle.indexAmm(wNFT) == mockAmm`
5. `test_tokenURI_prefix` — `tokenURI(1)` starts with `"data:application/json;base64,"`
6. `test_tokenURI_json_valid` — base64 decode + `vm.parseJson`, check `name`, `indexVersion`, `updatedAt`
7. `test_tokenURI_image_svg` — check `image` field starts with `"data:image/svg+xml;base64,"`
8. `test_tokenURI_collateral_populated` — after fixIndex, collateral array length matches assets
9. `test_svg_green_when_price_up` — mock oracle returns higher current price → no "red" in SVG
10. `test_svg_red_when_price_down` — mock oracle returns lower current price → contains `paint_linear_1_red`

### `test/EnvelopOracle_Test_a_ext.sol`

Test cases for oracle extensions:
1. `test_registerIndex_only_by_wNFT` — calling from other address reverts
2. `test_getIndexPrice_uses_chainlink` — registered without AMM → price from mock feed
3. `test_getIndexPrice_uses_amm` — registered with mock AMM adapter → price from adapter
4. `test_getIndexPrice_override_takes_precedence` — override set → override returned regardless of AMM
5. `test_setIndexPrice_by_authorized_updater`
6. `test_setIndexPrice_reverts_unauthorized`
7. `test_existing_oracle_tests_unaffected` — import + run existing `EnvelopOracle_Test_a_01`

---

## Reuse checklist

| Item | Location |
|------|----------|
| `IEnvelopOracle.CompactAsset` | `src/interfaces/IEnvelopOracle.sol` |
| `ET.Lock` | `src/utils/LibET.sol` |
| `Strings` | already imported in `WNFTV2Index.sol` |
| `Base64` | `@openzeppelin/contracts/utils/Base64.sol` (new import) |
| `onlyWnftOwner` | `Singleton721` |
| `_getWNFTV2Envelop721Storage()` | `WNFTV2Envelop721` — for `wnftData.locks` |
| `MockERC20`, `MockOracle`, `MockFeedRegistry` | `src/mock/` |
| `_getLatestPriceInUSD` | reused in oracle's new `getIndexPrice(address)` Chainlink path |

---

## Build & test

```bash
forge build

# New implementation tests
forge test --match-contract WNFTV2SmartIndex_Test -vvv

# Oracle extension tests
forge test --match-contract EnvelopOracle_Test_a_ext -vvv

# Regression: existing oracle tests must still pass
forge test --match-contract EnvelopOracle_Test -vvv

# Full suite
forge test -vvv
```

Manual verification: copy `tokenURI(1)` output, paste into browser address bar — JSON renders; `image` field renders as SVG with correct colors.
