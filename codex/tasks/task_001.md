# 1. Design new index implementation
## Index (Индекс) Envelop
Понятие **Индекс**, в контексте данного документа - это фиксированные набор активов(1),
обладюающих ценностью или доходностью(2), которая оценена и зафиксирована на момент создания(3) в единицах
базового актива(4). Индекс может иметь допольнительные параметры, например дату экспирации.
Опцион в общепринятом понимании,  тоже можно считать частным случаем Envelop Index.

## Problems
1. В текушей имплементации контракта индекса `./src/implWNFTV2Index.sol` используется
вот  такой URL https://api.envelop.is/dindex/ для tokenURI. Это централизованный бэкенд,  что не всегда хорошо.  
2. В версии протокола Envelop V2 каждый wNFT представляет собой отдельный контракт. Суть - он является
кошельком `SmartWallet`. Реестра записей остатков активов в нём не ведётся отдельно. Есть попытка 
отдельного ведения реестра остатков индекса в контракте  `Predicter`, который, однако,  не контролирует наличие  их
на балансе контракта. 
## Задача 
1. Design tokenURI method for ERC721 contract that returns fully on-chain base64-encoded JSON metadata without any external URLs. Кроме некоторых, я вноуказанных здесь.
2. Определиться, где лучше вести реестр активов индекса. Спроектировать этот контракт, с учётом понятия индекса envelop.
### Requirements:
tokenURI must return a data URI in this format: `data:application/json;base64,<base64_encoded_json>`
По возможности, используй в json OpenSea compatable fields. Especially for `attributes` array:
```json
{
  "trait_type":   "string",
  "value":        "string | number | float",
  "display_type": "number | boost_number | boost_percentage | date",
  "max_value":    "number"
}
```

JSON metadata structure:
```json
{
    "name": "Envelop Index",
    "description": "Envelop Index wNFT",
    "indexVersion": "<get from indexVersion() in parent contract>",
    "image": "data:image/svg+xml;base64,<base64_encoded_svg>",
    "external_url": "https://app.envelop.is/token/<chain_id>/<contract_address>/<token_id>",
    "attributes": [
        "<srart_index_price>", "<current_index_price>","<first_owner_address>",
        "each_erc20_token_amount", "each_erc20_token_price"
    ],
    "collateral":[
        {
            "amount": "91700744506503112",
            "tokenId": 1,
            "assetType": 2,
            "contractAddress": "0x6b175474e89094c44da98b954eedeac495271d0f",
            "decimals": "<For assetType = 2: erc20.deciamls(), else = 0>",
            "price": {"base_asset": "address", "price":"<price_from_oracle>", "price_decimals":"price_decimals"}
        },
        {"same object for each asset"}
  
    ],
    "locks":[
      {
        "param": 1739805126,
        "lockType": 0
      }
    ],
    "updatedAt": 1775366746
}
```
### Источники данных для collateral и цен
В версии протокола Envelop V2 каждый wNFT представляет собой отдельный контракт. Суть - он является
кошельком `SmartWallet`. Следовательно, узнать onchain набор актвов, которые на нём харнятся мы не можем.
Потому что мы не знаем, какие имеено erc20 токены были перевдены на адесс нашего индекса.
wNFT превращается в индекс в тот момент, когда создатель фиксирует набор
активов составляющих индекс и его сумарную стартовую цену.
#### Collateral amount
Если индекс создан (см. понятие Индекс), то список остатков для json нужно получать оттуда. 
Если у нас есть просто wNFT, то можно попробовать проверить onchain наличие балансf wNFT(SmartWallet)
в смарт контрактов популярных активов (erc20, erc721)

#### Collateral prices
Некоторый виды индексов предполоагают необходимость автоматического измерения
и фиксации стоимости набора активов индекса (см. `Predictor & EnvelopOracle`). В 
ряде  случаев (опцион) должна быть возможность продать/обменять активы onchain при выполненни 
определённых условий (см. `Predictor`). Следовательно, источником цены должен быть тот AMM,  на
котором предполагается обмен или продажда. Таким образом, скорее всего,  нужно вводить в индекс отдельый параметр - 
AMM. Это можно делать через immutable в контракте имплементации, либо в самом индексе

### Implementation details:
#### SVG
Image must also be fully on-chain — SVG generated in Solidity, then base64 encoded
Use OpenZeppelin Base64 library (`@openzeppelin/contracts/utils/Base64.sol`)
Use OpenZeppelin Strings library for uint to string conversion
All metadata generated dynamically from on-chain token state — no hardcoded strings
No IPFS links, no HTTP URLs anywhere
За основу возьми вот этот SVG. `./codex/tasks/default.svg` Внимательно изучи вёрстку
и подстановки параметров

#### Method signature:
```
solidityfunction tokenURI(uint256 tokenId) 
    public 
    view 
    override 
    returns (string memory)
```
Helper methods to implement:
```
_generateSVG(uint256 tokenId) — builds SVG string based on token properties
_generateJSON(uint256 tokenId) — assembles JSON string
_encodeBase64JSON(uint256 tokenId) — encodes JSON to base64 and wraps in data URI
```
Expected result:
Calling tokenURI(1) returns a string that:
Starts with data:application/json;base64,
After base64 decode contains valid JSON
JSON image field contains valid inline SVG
Can be pasted directly into browser address bar and renders correctly
Stack: Solidity 0.8.x, OpenZeppelin v5, Foundry

## Результат
Файл спецификации требований `./codex/tasks/spec_index_dec.md` для разработки
абстрактного смарт контракта с `tokenURI`, план реализации этих фич `./codex/tasks/plan_index_dec.md`

