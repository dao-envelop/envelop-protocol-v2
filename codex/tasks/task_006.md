# 6. Fork EnvelopOracle to use Pyth Network

## Проблема

Существующий контракт `src/utils/EnvelopOracle.sol` читает цены через Chainlink Feed Registry (`FeedRegistryInterface`). Однако токены, использованные в индекс-шаблонах фронтового приложения `indexpage-sdk/src/index_templates.json` для `chainId: 1` (Ethereum mainnet), **в Chainlink Feed Registry не зарегистрированы** — Chainlink не публикует USD-фиды для большинства из них (LDO, ETHFI, ENA, SKY, SYRUP, EUL, SPK, CAKE, LIT, FLUID, PENDLE, POL, ARB, STRK, IMX, ZRO, NEAR, ATH, RENDER, TAO, ONDO, CRCLon, SPYon, NVDAon, XAUT, BNB, TRX, WZEC и др.).

В то же время **Pyth Network** покрывает 35 из 37 уникальных адресов прямыми USD-фидами. Поэтому требуется отдельная имплементация оракла, читающая цены через Pyth.

## Что делать

> Этот таск решаем в новой ветке `task-006-envelop-oracle-pyth`. Перед началом — `git clone https://github.com/pyth-network/pyth-crosschain.git` в `/home/devops/codex-work/pyth-crosschain` и изучить skill'ы в `apps/mcp/skills/` (особенно EVM consumer / `pyth-sdk-solidity` / pull-pattern).

### v1 — чистый Pyth (первая итерация, отдельный коммит)

1. **Форкнуть** `src/utils/EnvelopOracle.sol` → создать **новый** файл `src/utils/EnvelopOraclePyth.sol`. **Не** трогать оригинал — он остаётся для сетей, где Chainlink Feed Registry применим.
2. **Сохранить публичный API** — все сигнатуры из `src/interfaces/IEnvelopOracle.sol` остаются 1:1:
   - `getIndexPrice(address _v2Index) external view returns (uint256)`
   - `getIndexPrice(CompactAsset[] calldata _assets) external view returns (uint256)`
   - `registerIndex()`, `deregisterIndex()`
   - `setIndexUpdater(address _wNFT, address _updater)`
   - `setIndexPrice(address _wNFT, uint256 _price)`
   - `isRegistered(address _wNFT) external view returns (bool)`
3. **Сохранить** также публичные хелперы для совместимости с вызывающим кодом:
   - `getPriceInUSD(address base) external view returns (uint256)` — 1e8-нормализованная USD-цена
   - `getPriceInUSDWithMeta(address base) external view returns (uint256 priceUsd, uint80 roundId, uint256 updatedAt, uint8 decimals)`
     - В Pyth-версии: `roundId = 0` (зафиксировать в NatSpec — у Pyth нет понятия round), `updatedAt = publishTime`, `decimals = 8`.
4. **Заменить источник цены**:
   - Удалить поля `FEED_REGISTRY` (`FeedRegistryInterface`), константу `DENOMINATION_USD`.
   - Добавить immutable `IPyth public immutable PYTH;` (тип из `@pythnetwork/pyth-sdk-solidity/IPyth.sol`).
   - Конструктор: `constructor(address _pyth, uint256 _maxStale) Ownable(msg.sender)` — позиция аргументов и `MAX_STALE` сохранены.
5. **Внутренний `_getLatestPriceInUSD`** переписать на:
   ```solidity
   function _getLatestPriceInUSD(address base)
       internal view
       returns (uint256 priceUsd, uint80 roundId, uint256 updatedAt, uint8 dec)
   {
       bytes32 feedId = priceFeedId[base];
       require(feedId != bytes32(0), "No feed");
       PythStructs.Price memory p = PYTH.getPriceNoOlderThan(feedId, MAX_STALE);
       require(p.price > 0, "Price <= 0");
       // Нормализация к 1e8: priceUsd = uint256(int256(p.price)) * 10^(expo+8)
       int32 targetExpo = -8;
       int32 shift = p.expo - targetExpo; // p.expo обычно -8 → shift = 0
       uint256 raw = uint256(uint64(p.price));
       if (shift >= 0) {
           priceUsd = raw * (10 ** uint32(shift));
       } else {
           priceUsd = raw / (10 ** uint32(-shift));
       }
       roundId = 0;
       updatedAt = p.publishTime;
       dec = 8;
   }
   ```
6. **Маппинг и owner-сеттеры**:
   ```solidity
   mapping(address token => bytes32 feedId) public priceFeedId;
   event FeedIdSet(address indexed token, bytes32 feedId);

   function setFeedId(address token, bytes32 feedId) external onlyOwner {
       priceFeedId[token] = feedId;
       emit FeedIdSet(token, feedId);
   }

   function setFeedIdBatch(address[] calldata tokens, bytes32[] calldata feedIds) external onlyOwner {
       require(tokens.length == feedIds.length, "len mismatch");
       for (uint256 i; i < tokens.length; ++i) {
           priceFeedId[tokens[i]] = feedIds[i];
           emit FeedIdSet(tokens[i], feedIds[i]);
       }
   }
   ```
7. **ETH_BASE** (`0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`) — назначается на Pyth ETH/USD feedId через тот же `setFeedId(ETH_BASE, 0xff61491a...)` в deploy-скрипте.
8. **Pull-update**: добавить вспомогательный `payable`-метод для удобного atomic-обновления + чтения:
   ```solidity
   function updateAndGetIndexPrice(address _v2Index, bytes[] calldata priceUpdate)
       external payable returns (uint256)
   {
       uint256 fee = PYTH.getUpdateFee(priceUpdate);
       PYTH.updatePriceFeeds{value: fee}(priceUpdate);
       // refund излишек
       if (msg.value > fee) {
           (bool ok,) = msg.sender.call{value: msg.value - fee}("");
           require(ok, "refund failed");
       }
       return this.getIndexPrice(_v2Index);
   }
   ```
   `priceUpdate` (VAA-blob) тянется off-chain с Hermes API: `https://hermes.pyth.network/api/latest_vaas?ids[]=<feedId>&ids[]=...`.
9. Дополнительный helper:
   ```solidity
   function getUpdateFee(bytes[] calldata priceUpdate) external view returns (uint256) {
       return PYTH.getUpdateFee(priceUpdate);
   }
   ```

### Регистр индексов и override-цены

Логика `registerIndex / deregisterIndex / setIndexUpdater / setIndexPrice / overrideIndexPrice / overridedPrices` копируется **полностью без изменений** — это часть `IEnvelopOracle` и не зависит от источника цены.

### v2 — фолбэки для непокрытых токенов (вторая итерация, отдельный коммит)

В v1 токены без Pyth USD-фида (`ETHx`, `SPECTRA`) при вызове `getPriceInUSD` ревертят с `"No feed"`. v2 добавляет два механизма:

1. **Derived feed** (для `ETHx`):
   ```solidity
   struct DerivedFeed { bytes32 ratioFeedId; bytes32 quoteFeedId; }
   mapping(address token => DerivedFeed) public derivedFeed;
   function setDerivedFeed(address token, bytes32 ratioFeedId, bytes32 quoteFeedId) external onlyOwner;
   ```
   В `_getLatestPriceInUSD`: если `priceFeedId[base] == 0`, проверить `derivedFeed[base]`; если есть — прочитать оба фида, перемножить (`ETHX/ETH × ETH/USD`).

2. **AMM TWAP fallback** (для `SPECTRA`):
   ```solidity
   mapping(address token => address adapter) public tokenFallbackAdapter;
   function setFallbackAdapter(address token, address adapter) external onlyOwner;
   ```
   Адаптер — `IAMMPriceAdapter` (см. `src/interfaces/IAMMPriceAdapter.sol`), обязан возвращать TWAP с окном ≥30 мин (требование уже описано в адаптере). В `_getLatestPriceInUSD`: если ни `priceFeedId`, ни `derivedFeed` не настроены — обратиться к адаптеру.

> **Chainlink-фолбэк** не предусмотрен: у этих токенов нет Chainlink-фидов на mainnet, поэтому единственный реалистичный on-chain путь для SPECTRA — Uniswap V3 TWAP.

## Маппинг address → Pyth feedId (Ethereum mainnet)

Используется в deploy-скрипте через `setFeedIdBatch`.

| # | address | symbol | Pyth feedId | Покрытие |
|---|---------|--------|-------------|----------|
| 1 | 0x5a98fcbea516cf06857215779fd812ca3bef1b32 | LDO | 0xc63e2a7f37a04e5e614c07238bedb25dcc38927fba8fe890597a593c0b2fa4ad | v1 |
| 2 | 0xFe0c30065B384F05761f15d0CC899D4F9F9Cc0eB | ETHx | — (derived: ETHX/ETH `0x1b8eb073e2a900cdf1f6ee37ddab4869a4400499ec6e52f3e268a93f46c55429` × ETH/USD) | **v2** |
| 3 | 0x01791F726B4103694969820be083196cC7c045fF | ETHFI | 0xb27578a9654246cb0a2950842b92330e9ace141c52b63829cc72d5c45a5a595a | v1 |
| 4 | 0x57e114B691Db790C35207b2e685D4A43181e6061 | ENA | 0xb7910ba7322db020416fcac28b48c01212fd9cc8fbcbaf7d30477ed8605f6bd4 | v1 |
| 5 | 0x56072C95FAA701256059aa122697B133aDEd9279 | SKY | 0xa483243eed64ca27a1f6e26385b7d1e0d07e9fe264bb6903efb3efc4689d3fe7 | v1 |
| 6 | 0x6a89228055c7c28430692e342f149f37462b478b | SPECTRA | — (Uniswap V3 TWAP через `IAMMPriceAdapter`) | **v2** |
| 7 | 0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9 | AAVE | 0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445 | v1 |
| 8 | 0x58d97b57bb95320f9a05dc918aef65434969c2b2 | MORPHO | 0x5b2a4c542d4a74dd11784079ef337c0403685e3114ba0d9909b5c7a7e06fdc42 | v1 |
| 9 | 0x643C4E15d7d62Ad0aBeC4a9BD4b001aA3Ef52d66 | SYRUP (Maple) | 0xed86e0c6321d790302e5d88751995ebc9079273e549005d68a83ba72e48ff1ce | v1 |
| 10 | 0xd9fcd98c322942075a5c3860693e9f4f03aae07b | EUL (Euler) | 0xa7adc417fe7e862494b488e89d88ab23f468661b63542d8f719da8f77e34c51f | v1 |
| 11 | 0xc20059e0317DE91738d13af027DfC4a50781b066 | SPK (Spark) | 0x88a17f294aa817de3f22d5b1ebf2b4e5979e252264085f875eb9849eefeb718d | v1 |
| 12 | 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984 | UNI | 0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501 | v1 |
| 13 | 0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898 | CAKE | 0x2356af9529a1064d41e32d617e2ce1dca5733afa901daba9e2b68dee5d53ecf9 | v1 |
| 14 | 0x232ce3bd40fcd6f80f3d55a522d03f25df784ee2 | LIT (Lighter) | 0xc0c83f00c39165892d55dcd17ade2191e289697e2ac132d9ab721e20834e2a9e | v1 |
| 15 | 0x6f40d4a6237c257fff2db00fa0510deeecd303eb | FLUID | 0x47d462d8bac4c29b6ae1792029b9b92c8adea12ed22155bfc22f481287f1e349 | v1 |
| 16 | 0x4B1E80cAC91e2216EEb63e29B957eB91Ae9C2Be8 | CRV | 0xa19d04ac696c7a6616d291c7e5d1377cc8be437c327b75adb5dc1bad745fcae8 | v1 |
| 17 | 0x808507121b80c02388fad14726482e061b8da827 | PENDLE | 0x9a4df90b25497f66b1afb012467e316e801ca3d839456db028892fe8c70c8016 | v1 |
| 18 | 0x455e53CBB86018Ac2B8092FdCd39d8444aFFC3F6 | POL | 0xffd11c5a1cfd42f80afb2df4d9f264c15f956d68153335374ec10722edd70472 | v1 |
| 19 | 0xB50721BCf8d664c30412Cfbc6cf7a15145234ad1 | ARB | 0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5 | v1 |
| 20 | 0xca14007eff0db1f8135f4c25b34de49ab0d42766 | STRK | 0x6a182399ff70ccf3e06024898942028204125a819e519a335ffa4579e66cd870 | v1 |
| 21 | 0xf57e7e7c23978c3caec3c3548e3d615c346e79ff | IMX | 0x941320a8989414874de5aa2fc340a75d5ed91fdff1613dd55f83844d52ea63a2 | v1 |
| 22 | 0x514910771af9ca656af840dff83e8264ecf986ca | LINK | 0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221 | v1 |
| 23 | 0x6985884C4392D348587B19cb9eAAf157F13271cd | ZRO (LayerZero) | 0x3bd860bea28bf982fa06bcf358118064bb114086cc03993bd76197eaab0b8018 | v1 |
| 24 | 0x77e06c9eccf2e797fd462a92b6d7642ef85b0a44 | NEAR | 0xc415de8d2eba7db216527dff4b60e8f3a5311c740dadb233e13e12547e226750 | v1 |
| 25 | 0xbe0Ed4138121EcFC5c0E56B40517da27E6c5226B | ATH (Aethir) | 0xf6b551a947e7990089e2d5149b1e44b369fcc6ad3627cb822362a2b19d24ad4a | v1 |
| 26 | 0x44ff8620b8cA30902395A7bD3F2407e1A091BF73 | RENDER | 0x3d4a2bd9535be6ce8059d75eadeba507b043257321aa544717c56fa19b49e35d | v1 |
| 27 | 0x85f17cf997934a597031b2e18a9ab6ebd4b9f6a4 | TAO (wTAO) | 0x410f41de235f2db824e562ea7ab2d3d3d4ff048316c61d629c0b93f58584e1af | v1 |
| 28 | 0xfaba6f8e4a5e8ab82f62fe7c39859fa577269be3 | ONDO | 0xd40472610abe56d36d065a0cf889fc8f1dd9f3b7f2a478231a5fc6df07ea5ce3 | v1 |
| 29 | 0x3632dea96a953c11dac2f00b4a05a32cd1063fae | CRCLon (Circle, Equity) | 0x92b8527aabe59ea2b12230f7b532769b133ffb118dfbd48ff676f14b273f1365 | v1 (RTH only) |
| 30 | 0xFeDC5f4a6c38211c1338aa411018DFAf26612c08 | SPYon (S&P500, Equity) | 0x19e09bb805456ada3979a7d1cbb4b6d63babc3a0f8e8a9509f68afa5c4c11cd5 | v1 (RTH only) |
| 31 | 0x2d1f7226bd1f780af6b9a49dcc0ae00e8df4bdee | NVDAon (NVIDIA, Equity) | 0xb1073854ed24cbc755dc527418f52b7d271f6cc967bbf8d8129112b18860a593 | v1 (RTH only) |
| 32 | 0x68749665ff8d2d112fa859aa293f07a622782f38 | XAUT | 0x44465e17d2e9d390e70c999d5a11fda4f092847fcd2e3e5aa089d96c98a30e67 | v1 |
| 33 | 0x2260fac5e5542a773aa44fbcfedf7c193bc2c599 | WBTC | 0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33 | v1 |
| 34 | 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE (ETH_BASE) | ETH | 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace | v1 |
| 35 | 0xB8c77482e45F1F44dE1745F52C74426C631bDD52 | BNB | 0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f | v1 |
| 36 | 0x50327c6c5a14dcade707abad2e27eb517df87ab5 | TRX | 0x67aed5a24fdad045475e7195c98a98aea119c763f272d4523f5bac93a4f33c2b | v1 |
| 37 | 0x4A64515E5E1d1073e83f30cB97BEd20400b66E10 | WZEC (через ZEC/USD) | 0xbe9b59d178f0d6a97ab4c343bff2aa69caa1eaae3e9048a65788c529b125bb24 | v1 |

**Pyth contract на Ethereum mainnet:** `0x4305FB66699C3B2702D4d05CF36551390A4c69C6`.

**Покрытие:** v1 → 35/37; v2 → 37/37.

**Внимание для equity-фидов (CRCLon, SPYon, NVDAon):** Pyth публикует их только в часы NYSE (9:30–16:00 ET, будни). Вне сессии — `getPriceNoOlderThan` ревертит. Это надо учесть при выборе `MAX_STALE` (рекомендация — 3600 с для крипты; для equity использовать отдельный экземпляр оракла с бóльшим окном или fallback на cached-цену).

## Источники данных

- **Адресы токенов (chainId 1):** `/home/devops/codex-work/indexpage-sdk/src/index_templates.json` — шаблоны `liquid-staking-yield`, `lending-credit`, `dex-liquidity`, `l2-infrastructure`, `ai-depin`, `rwa-tokenized`, `l1-foundations`.
- **Pyth Hermes API:** `https://hermes.pyth.network/v2/price_feeds` (метаданные), `https://hermes.pyth.network/api/latest_vaas?ids[]=…` (VAA для `updatePriceFeeds`).
- **Pyth Solidity SDK:** `forge install pyth-network/pyth-sdk-solidity` → `lib/pyth-sdk-solidity`.
- **Skill `apps/mcp/skills/`** из `https://github.com/pyth-network/pyth-crosschain.git`.

## Критерии успеха

### v1
1. Создан `src/utils/EnvelopOraclePyth.sol`, реализующий `IEnvelopOracle`.
2. Все публичные сигнатуры из `IEnvelopOracle` сохранены 1:1 — ABI совпадает (проверить `forge inspect EnvelopOraclePyth abi`).
3. `getPriceInUSD(base)` возвращает 1e8-нормализованную цену из Pyth (после того как `updatePriceFeeds` был вызван в этой или недавней транзакции).
4. Deploy-скрипт `script/DeployEnvelopOraclePyth.s.sol` (форк `script/DeployEnvelopOracle.s.sol`):
   - принимает `PYTH = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6`, `MAX_STALE = 3600`,
   - выполняет `setFeedIdBatch(...)` для 35 покрытых токенов из таблицы выше.
5. Unit-тесты `test/EnvelopOraclePyth_*.t.sol` (по образцу `test/EnvelopOracle_Test_ai_01.t.sol`):
   - mock-Pyth, проверка нормализации экспоненты (`expo = -8`, `-6`, `-10`),
   - revert при `feedId = 0`,
   - revert при `price <= 0`,
   - revert при staleness (`vm.warp(... + MAX_STALE + 1)`).
6. Fork-тест `test/fork/EnvelopOraclePyth_a_01.t.sol` (по образцу `test/fork/EnvelopOracle_a_01.t.sol`):
   - форк Ethereum mainnet,
   - `vm.ffi(["curl", "https://hermes.pyth.network/api/latest_vaas?ids[]=..."])` → распарсить VAA,
   - `updatePriceFeeds`, затем `getPriceInUSD(WBTC/ETH/AAVE/UNI/LINK)`,
   - asserts: `price > 0`, в разумном коридоре (например `priceWBTC ∈ [20_000e8, 200_000e8]`).
7. `CHANGELOG.md` (раздел Unreleased): добавлен `EnvelopOraclePyth`.

### v2 (после v1 — отдельный коммит)
8. Добавлены `setDerivedFeed`, `setFallbackAdapter`, маппинги и логика их использования в `_getLatestPriceInUSD`.
9. ETHx (`0xFe0c…c0eB`) возвращает корректную derived-цену = `ETHX/ETH × ETH/USD`, 1e8.
10. SPECTRA (`0x6a89…478b`) возвращает TWAP-цену через `IAMMPriceAdapter` (адрес адаптера задаётся в deploy-скрипте), 1e8.
11. Публичные сигнатуры **не менялись** между v1 и v2.

## Critical files

- Источник для форка: `src/utils/EnvelopOracle.sol`
- Интерфейс (не менять): `src/interfaces/IEnvelopOracle.sol`
- AMM-адаптер для v2: `src/interfaces/IAMMPriceAdapter.sol`
- Deploy-скрипт-образец: `script/DeployEnvelopOracle.s.sol`
- Test-образец (unit): `test/EnvelopOracle_Test_ai_01.t.sol`
- Test-образец (fork): `test/fork/EnvelopOracle_a_01.t.sol`
- Mock: `src/mock/MockOracle.sol`
- SDK: `lib/pyth-sdk-solidity` (`forge install pyth-network/pyth-sdk-solidity`)

## Ветка и коммиты

- Ветка: `task-006-envelop-oracle-pyth` от `master`.
- Коммит 1 (v1): `feat: add EnvelopOraclePyth with Pyth Network feeds #6`
- Коммит 2 (v2): `feat: add derived-feed and AMM TWAP fallback for EnvelopOraclePyth #6`
- Каждый последующий фикс — отдельный коммит с тегом `#6`.

## Статус

**Открыт.** План: `/home/devops/.claude/plans/src-index-templates-json-zesty-key.md`.

---

## Verification (2026-05-21)

Проверка `_v1FeedMap()` из `script/DeployEnvelopOraclePyth.s.sol` (41 запись, индексы 0..40) по трём осям:

1. **Oracle on-chain** — `priceFeedId(token)` развёрнутого `EnvelopOraclePyth` (`0x10a877328959d5b655bc0bba03aba2b383114bfa`, mainnet) сравнено с feedId в скрипте.
2. **Hermes off-chain** — `https://hermes.pyth.network/v2/updates/price/latest?ids[]=…&parsed=true` (через `curl` UA, иначе 403).
3. **PYTH on-chain без staleness** — `PYTH.getPriceUnsafe(feedId)` на `0x4305FB66699C3B2702D4d05CF36551390A4c69C6`. Селектор `0x14aebe68` = `PriceFeedNotFound()` — фид никогда не пушился через `updatePriceFeeds` в этот контракт.

RPC: `https://rpc.envelop.is/eth`. Скрипт верификации: `/tmp/task6_verify/verify.py`.

### Сводная таблица

| # | Symbol | Token | feedId (script) | Oracle has it? | Hermes USD | PYTH.getPriceUnsafe USD | PYTH publishTime |
|---|---|---|---|---|---|---|---|
| 0 | LDO | `0x5A98FcBE…1B32` | `0xc63e2a7f…2fa4ad` | YES | 0.3540 | 0.3584 | 1779357024 |
| 1 | ETHFI | `0x01791F72…45fF` | `0xb27578a9…5a595a` | YES | 0.3783 | 0.3832 | 1779357024 |
| 2 | ENA | `0x57e114B6…6061` | `0xb7910ba7…5f6bd4` | YES | 0.1044 | 0.1063 | 1779357024 |
| 3 | SKY | `0x56072C95…9279` | `0xa483243e…9d3fe7` | YES | 0.0708 | 0.0707 | 1779357024 |
| 4 | AAVE | `0x7Fc66500…DaE9` | `0x2b9ab1e9…e47445` | YES | 88.1194 | 87.6915 | 1779286652 |
| 5 | MORPHO | `0x58D97B57…c2B2` | `0x5b2a4c54…6fdc42` | YES | 1.8957 | REVERT `PriceFeedNotFound` | — |
| 6 | SYRUP | `0x643C4E15…2d66` | `0xed86e0c6…8ff1ce` | YES | 0.2001 | REVERT `PriceFeedNotFound` | — |
| 7 | EUL | `0xd9Fcd98c…E07b` | `0xa7adc417…34c51f` | YES | 1.2816 | 1.2010 | 1776292317 |
| 8 | SPK | `0xc20059e0…b066` | `0x88a17f29…eb718d` | YES | 0.0295 | REVERT `PriceFeedNotFound` | — |
| 9 | UNI | `0x1f9840a8…F984` | `0x78d185a7…171501` | YES | 3.5911 | 3.6191 | 1779357120 |
| 10 | CAKE | `0x152649eA…c898` | `0x2356af95…53ecf9` | YES | 1.4383 | 1.4534 | 1779357143 |
| 11 | LIT | `0x232CE3bd…4Ee2` | `0xc0c83f00…4e2a9e` | YES | 1.3604 | 1.4010 | 1779357161 |
| 12 | FLUID | `0x6f40d4A6…03eb` | `0x47d462d8…f1e349` | YES | 1.6444 | 1.6519 | 1779357186 |
| 13 | **CRV** | `0x4B1E80cA…2Be8` | `0xa19d04ac…5fcae8` | **MISMATCH** (on-chain: `0x0a0408d6…830996`) | 0.2314 | 0.2340 | 1779357209 |
| 14 | PENDLE | `0x80850712…a827` | `0x9a4df90b…0c8016` | YES | 1.8188 | 1.8413 | 1779357024 |
| 15 | POL | `0x455e53CB…C3F6` | `0xffd11c5a…d70472` | YES | 0.0908 | 0.2802 (stale) | 1740409566 |
| 16 | ARB | `0xB50721BC…4ad1` | `0x3fa42528…1adcf5` | YES | 0.1090 | 0.7212 (stale) | 1735740000 |
| 17 | STRK | `0xCa14007E…2766` | `0x6a182399…6cd870` | YES | 0.0436 | 0.3460 (stale) | 1730728384 |
| 18 | IMX | `0xF57e7e7C…79fF` | `0x941320a8…ea63a2` | YES | 0.1716 | REVERT `PriceFeedNotFound` | — |
| 19 | LINK | `0x51491077…86CA` | `0x8ac0c70f…04d221` | YES | 9.5635 | 15.2006 (stale) | 1741504973 |
| 20 | ZRO | `0x6985884C…71cd` | `0x3bd860be…0b8018` | YES | 1.3645 | REVERT `PriceFeedNotFound` | — |
| 21 | NEAR | `0x77E06c9e…0A44` | `0xc415de8d…226750` | YES | 1.7474 | REVERT `PriceFeedNotFound` | — |
| 22 | ATH | `0xbe0Ed413…226B` | `0xf6b551a9…24ad4a` | YES | 0.0060 | REVERT `PriceFeedNotFound` | — |
| 23 | RENDER | `0x44ff8620…BF73` | `0x3d4a2bd9…49e35d` | YES | 1.9026 | REVERT `PriceFeedNotFound` | — |
| 24 | TAO | `0x85F17Cf9…f6a4` | `0x410f41de…84e1af` | YES | 279.9987 | REVERT `PriceFeedNotFound` | — |
| 25 | ONDO | `0xfAbA6f8e…9BE3` | `0xd4047261…ea5ce3` | YES | 0.3990 | 0.2533 (stale) | 1775727471 |
| 26 | CRCLon | `0x3632DEa9…3fAE` | `0x92b8527a…3f1365` | YES | 111.6055 | REVERT `PriceFeedNotFound` | — |
| 27 | SPYon | `0xFeDC5f4a…2c08` | `0x19e09bb8…c11cd5` | YES | 740.9496 | 455.4900 (stale) | 1700680342 |
| 28 | NVDAon | `0x2D1F7226…bDEE` | `0xb1073854…60a593` | YES | 223.5000 | 187.6100 (stale) | 1768585548 |
| 29 | XAUT | `0x68749665…2F38` | `0x44465e17…a30e67` | YES | 4,510.2232 | 5,173.9195 (stale) | 1772001841 |
| 30 | WBTC | `0x2260FAC5…C599` | `0xc9d8b075…2ffc33` | YES | 77,071.9873 | 68,051.8518 (stale) | 1772587897 |
| 31 | ETH | `0xEeeeeEee…EEeE` | `0xff61491a…fd0ace` | YES | 2,113.3828 | 2,119.8446 | 1779359149 |
| 32 | BNB | `0xB8c77482…DD52` | `0x2f95862b…101c4f` | YES | 648.9494 | 631.9807 (stale) | 1740409566 |
| 33 | TRX | `0x50327c6c…7AB5` | `0x67aed5a2…f33c2b` | YES | 0.3615 | 0.1537 (stale) | 1727961560 |
| 34 | WZEC | `0x4A64515E…6E10` | `0xbe9b59d1…25bb24` | YES | 658.7403 | REVERT `PriceFeedNotFound` | — |
| 35 | **ETHx*** | `0xFe0c3006…c0eB` | `0xb27578a9…5a595a` | YES (но feedId = ETHFI) | 0.3783 | 0.3832 | 1779357024 |
| 36 | IOTX | `0x6fB3e0A2…4d69` | `0xa8310314…d1e6d8` | YES | 0.0044 | REVERT `PriceFeedNotFound` | — |
| 37 | WFIL | `0x6e1A19F2…94DE` | `0x150ac9b9…628c0e` | YES | 0.9731 | REVERT `PriceFeedNotFound` | — |
| 38 | COINon | `0xF042cfa8…493b` | `0x42ded7a3…e9d6b6` | YES | 202.3202 | REVERT `PriceFeedNotFound` | — |
| 39 | QQQon | `0x0e397938…9aBa` | `0x9695e2b9…30452d` | YES | 713.0000 | 391.1475 (stale) | 1700680342 |
| 40 | GOOGLon | `0xbA47214e…fEDc` | `0x07d24bb7…0836b4` | YES | 388.7629 | REVERT `PriceFeedNotFound` | — |

### Итоги по трём проверкам

- **Oracle on-chain (`priceFeedId`):** 40/41 совпадает со скриптом. **CRV (idx 13) — расхождение:** в скрипте `0xa19d04ac…5fcae8` (`Crypto.CRV/USD` по Hermes), в контракте сохранён `0x0a0408d6…830996` (этот feedId Hermes возвращает цену, но не находится через `query=CRV` — скорее всего deprecated/тестовый CRV-фид).
- **Hermes off-chain:** **41/41 OK** — для всех feedId Hermes отдаёт валидную цену.
- **PYTH on-chain без staleness (`getPriceUnsafe`):** **26/41 возвращают цену, 15/41 ревертят** с селектором `0x14aebe68` = `PriceFeedNotFound()`. Эти 15 фидов **никогда** не пушились в mainnet-PYTH; первый вызов `getPriceUnsafe` после того, как кто-нибудь сделает `updatePriceFeeds(vaa)`, начнёт возвращать цену.

Список 15 фидов без on-chain цены: MORPHO, SYRUP, SPK, IMX, ZRO, NEAR, ATH, RENDER, TAO, CRCLon, WZEC, IOTX, WFIL, COINon, GOOGLon. Все они доступны через Hermes — оракл сможет читать их через pull-pattern (`updateAndGetIndexPrice`), но **обычный** `getPriceInUSD` (без предварительного `updatePriceFeeds`) для них упадёт с `PriceFeedNotFound`.

### Дополнительные находки

1. **`new address[](35)` vs 41 записи (`script/DeployEnvelopOraclePyth.s.sol:49`).** Скрипт объявляет фиксированный массив длиной 35, но user-added строки записывают в индексы 35..40 — попытка повторного запуска `forge script` ревертнётся с Panic 0x32 (out-of-bounds). При этом on-chain все 41 значения присутствуют → значит либо при последнем деплое массив локально был расширен до 41, либо 6 хвостовых пар проставлены отдельным вызовом `setFeedIdBatch`/`setFeedId` от owner-а. Чтобы скрипт оставался воспроизводимым, нужно обновить аллокацию: `tokens = new address[](41); feeds = new bytes32[](41);`.

2. **idx 35 — `ETHx` с feedId ETHFI.** Адрес `0xFe0c30065…c0eB` — это **ETHx**, не ETHFI (см. ряд 2 в таблице задачи). По спецификации задачи ETHx должен идти **по v2-derived схеме** (`ETHX/ETH × ETH/USD`), а не быть в `priceFeedId`-маппинге v1. Текущее значение `priceFeedId[ETHx] = 0xb27578a9…` (ETHFI) — это копипаст-ошибка: на запросе цены `getPriceInUSD(ETHx)` будет возвращена цена ETHFI, а не ETHx. Удалить/перенести в `setDerivedFeed(ETHx, …)` после v2.

3. **Stale-цены в PYTH-контракте.** Часть фидов имеет `publishTime` из 2023–2025 (ARB 2025-01-01, STRK 2024-11, SPYon/QQQon 2023-11 и т.д.). `getPriceUnsafe` их вернёт, но `getPriceNoOlderThan(MAX_STALE=3600)`, который использует `_getLatestPriceInUSD`, **ревертнёт**. Для всех индексов с такими активами рабочий путь — `updateAndGetIndexPrice(_v2Index, priceUpdate)`, где `priceUpdate` подтянут с Hermes (`/api/latest_vaas?ids[]=…`).

### Рекомендации

- [ ] В `script/DeployEnvelopOraclePyth.s.sol:49-50` поднять размер массивов до 41 (или динамически по числу строк).
- [ ] **CRV (idx 13) — скрипт не правим** (по запросу пользователя). Предлагаемый feedId для on-chain коррекции (без изменения исходника):
  - токен `0x4B1E80cAC91e2216EEb63e29B957eB91Ae9C2Be8` (CRV)
  - feedId: `0xa19d04ac696c7a6616d291c7e5d1377cc8be437c327b75adb5dc1bad745fcae8` (`Crypto.CRV/USD`, подтверждено через Hermes `query=CRV&asset_type=crypto`)
  - команда: `cast send <ORACLE> "setFeedId(address,bytes32)" 0x4B1E80cAC91e2216EEb63e29B957eB91Ae9C2Be8 0xa19d04ac696c7a6616d291c7e5d1377cc8be437c327b75adb5dc1bad745fcae8 --rpc-url $RPC --account <owner>`
- [ ] Исправить idx 35: убрать ETHx из v1-маппинга (либо в v2 через `setDerivedFeed`).
- [ ] В тестах фронта для индексов, содержащих фиды из списка `PriceFeedNotFound`, использовать pull-обновление через Hermes до чтения цены.

