// SPDX-License-Identifier: MIT
// ENVELOP(NIFTSY) protocol V2 for NFT. Onchain Oracle (Pyth Network variant)
pragma solidity ^0.8.28;

/// forge-lint: disable-next-line(unaliased-plain-import)
import "../interfaces/IEnvelopOracle.sol";
import "../interfaces/IIndexAssets.sol";
import "../interfaces/IAMMPriceAdapter.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/// @title EnvelopOraclePyth
/// @notice Drop-in replacement for EnvelopOracle that sources prices from Pyth Network
///         instead of Chainlink Feed Registry. Public ABI matches IEnvelopOracle 1:1 so the
///         deployment target (mainnet, L2, BSC, etc.) is selected by which oracle address is
///         wired into Predicter / WNFTV2SmartIndex.
/// @dev Pyth uses a pull-update model: an off-chain client must fetch a VAA from Hermes and
///      submit it via {updatePriceFeeds} (or via {updateAndGetIndexPrice}) before view reads
///      reflect fresh data. {getPriceNoOlderThan} enforces freshness via MAX_STALE.
contract EnvelopOraclePyth is IEnvelopOracle, Ownable {
    // =========================================================
    //                     Price Oracle part
    // =========================================================

    /// @notice Pyth contract (e.g. 0x4305FB66699C3B2702D4d05CF36551390A4c69C6 on Ethereum mainnet)
    IPyth public immutable PYTH;

    /// @notice Sentinel address used by callers to denote native ETH (instead of an ERC20)
    address public constant ETH_BASE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Maximum allowed staleness for a price feed, in seconds
    uint256 public immutable MAX_STALE;

    /// @notice ERC20 token address (or ETH_BASE) → Pyth price feed id
    mapping(address token => bytes32 feedId) public priceFeedId;

    // =========================================================
    //                    Index registry
    // =========================================================

    mapping(address wNFT => uint256 price)   public overridedPrices;

    // =========================================================
    //                         Events
    // =========================================================

    /// @notice Emitted when price is successfully read from Pyth.
    /// @dev `roundId` is always 0 — Pyth has no round concept; field kept for ABI parity.
    event PriceRead(address indexed base, uint256 priceUsd, uint80 roundId, uint256 updatedAt);

    event EnvelopIndexRegistered(address indexed wNFT);
    event EnvelopIndexDeregistered(address indexed wNFT);
    event EnvelopIndexPriceSet(address indexed wNFT, uint256 price, address indexed setter);
    event FeedIdSet(address indexed token, bytes32 feedId);

    // =========================================================
    //                        Constructor
    // =========================================================

    /**
     * @param _pyth     Address of the Pyth contract on the target chain.
     * @param _maxStale Maximum allowed staleness for a price (seconds).
     */
    constructor(address _pyth, uint256 _maxStale) Ownable(msg.sender) {
        PYTH = IPyth(_pyth);
        MAX_STALE = _maxStale;
    }

    // =========================================================
    //                  Feed id administration
    // =========================================================

    /// @notice Set the Pyth feed id for a token (or ETH_BASE).
    function setFeedId(address token, bytes32 feedId) external onlyOwner {
        priceFeedId[token] = feedId;
        emit FeedIdSet(token, feedId);
    }

    /// @notice Batch variant of {setFeedId}.
    function setFeedIdBatch(address[] calldata tokens, bytes32[] calldata feedIds) 
        external 
        onlyOwner 
    {
        require(tokens.length == feedIds.length, "len mismatch");
        for (uint256 i; i < tokens.length; ++i) {
            priceFeedId[tokens[i]] = feedIds[i];
            emit FeedIdSet(tokens[i], feedIds[i]);
        }
    }

    // =========================================================
    //                    Public price helpers
    // =========================================================

    /**
     * @notice Get latest price for a base asset in USD, normalized to 1e8.
     * @param base Asset address (e.g., token address) to query.
     * @return priceUsd Latest price in 1e8 decimals.
     */
    function getPriceInUSD(address base) public view returns (uint256 priceUsd) {
        (priceUsd,,,) = _getLatestPriceInUSD(base);
    }

    /**
     * @notice Get latest price + metadata for a base asset in USD.
     * @dev `roundId` is always 0 (Pyth has no rounds); `decimals` is always 8 (price is normalized).
     * @param base Asset address to query.
     * @return priceUsd Latest price in 1e8 decimals.
     * @return roundId Always 0 — kept for ABI parity with Chainlink-based EnvelopOracle.
     * @return updatedAt Pyth publishTime of the latest stored update for this feed.
     * @return decimals Always 8 (price is normalized internally).
     */
    function getPriceInUSDWithMeta(address base)
        external
        view
        returns (uint256 priceUsd, uint80 roundId, uint256 updatedAt, uint8 decimals)
    {
        return _getLatestPriceInUSD(base);
    }

    // =========================================================
    //               IEnvelopOracle — index price
    // =========================================================

    /**
     * @notice Returns the USD price of a registered index wNFT.
     * Priority:
     *   1. overridedPrices[_v2Index] != 0  → manual/Predicter override
     *   2. isRegistered[_v2Index]          → auto-compute via IIndexAssets callback
     *   3. else → 0
     */
    function getIndexPrice(address _v2Index) external view returns (uint256) {
        // 1. Manual/Predicter override
        if (overridedPrices[_v2Index] != 0) return overridedPrices[_v2Index];
        return 0;
    }

    function getIndexPrice(CompactAsset[] calldata _assets) external view returns (uint256 total) {
        for (uint256 i = 0; i < _assets.length; i++) {
            if (_assets[i].token != ETH_BASE) {
                total += _assets[i].amount * getPriceInUSD(_assets[i].token)
                  / (10**IERC20Metadata(_assets[i].token).decimals());
            } else {
                total += _assets[i].amount * getPriceInUSD(_assets[i].token)
                  / 10**18;
            }
        }
    }


    // =========================================================
    //               Legacy owner price override
    // =========================================================

    function overrideIndexPrice(address _v2Index, uint256 _price) external onlyOwner {
        require(_price > 0, "Price <= 0");
        overridedPrices[_v2Index] = _price;
    }

    // =========================================================
    //                    Pyth pull-update helpers
    // =========================================================

    /// @notice Forward to PYTH.getUpdateFee for off-chain fee discovery.
    function getUpdateFee(bytes[] calldata updateData) external view returns (uint256) {
        return PYTH.getUpdateFee(updateData);
    }

    /// @notice Pay-and-update Pyth feeds. Refunds any overpayment to msg.sender.
    function updatePriceFeeds(bytes[] calldata updateData) external payable {
        uint256 fee = PYTH.getUpdateFee(updateData);
        require(msg.value >= fee, "Insufficient fee");
        PYTH.updatePriceFeeds{value: fee}(updateData);
        if (msg.value > fee) {
            (bool ok,) = msg.sender.call{value: msg.value - fee}("");
            require(ok, "refund failed");
        }
    }

    /// @notice Atomic helper: push price update VAAs, then read getIndexPrice in same tx.
    function updateAndGetIndexPrice(address _v2Index, bytes[] calldata updateData)
        external
        payable
        returns (uint256)
    {
        uint256 fee = PYTH.getUpdateFee(updateData);
        require(msg.value >= fee, "Insufficient fee");
        PYTH.updatePriceFeeds{value: fee}(updateData);
        if (msg.value > fee) {
            (bool ok,) = msg.sender.call{value: msg.value - fee}("");
            require(ok, "refund failed");
        }
        return this.getIndexPrice(_v2Index);
    }

    // =========================================================
    //                     Internal price helper
    // =========================================================

    /**
     * @dev Internal helper to fetch and normalize USD price from Pyth.
     * @param base Asset address to query.
     * @return priceUsd Price normalized to 1e8 decimals.
     * @return roundId Always 0 (Pyth has no rounds).
     * @return updatedAt Pyth publishTime.
     * @return dec Always 8.
     */
    function _getLatestPriceInUSD(address base)
        internal
        view
        returns (uint256 priceUsd, uint80 roundId, uint256 updatedAt, uint8 dec)
    {
        bytes32 feedId = priceFeedId[base];
        require(feedId != bytes32(0), "No feed");

        PythStructs.Price memory p = PYTH.getPriceNoOlderThan(feedId, MAX_STALE);
        require(p.price > 0, "Price <= 0");

        priceUsd = _normalizeTo1e8(p);
        roundId = 0;
        updatedAt = p.publishTime;
        dec = 8;
    }

    /**
     * @dev Normalize a Pyth price to 1e8 decimals (target expo = -8).
     *      Pyth reports price = p.price * 10^p.expo; typical crypto feeds have expo = -8 → no shift.
     * @param p Pyth price struct (caller must ensure p.price > 0).
     * @return priceUsd Price normalized to 1e8 decimals.
     */
    function _normalizeTo1e8(PythStructs.Price memory p) private pure returns (uint256 priceUsd) {
        int32 shift = p.expo - int32(-8);
        uint256 raw = uint256(uint64(p.price));
        if (shift >= 0) {
            // forge-lint: disable-next-line(unsafe-typecast) — shift is non-negative in this branch
            priceUsd = raw * (10 ** uint32(shift));
        } else {
            // forge-lint: disable-next-line(unsafe-typecast) — -shift is non-negative in this branch
            priceUsd = raw / (10 ** uint32(-shift));
        }
    }

    /**
     * @notice Latest Pyth price for `base` in USD (1e8) WITHOUT any staleness check.
     * @dev Uses Pyth {getPriceUnsafe}; the returned price may be arbitrarily old.
     *      Callers MUST inspect `publishTime` to decide if it is fresh enough.
     *      Unlike {getPriceInUSD}, this never reverts on stale data.
     * @param base Asset address (or ETH_BASE) to query.
     * @return price Price normalized to 1e8 decimals.
     * @return publishTime Pyth publishTime of the returned price.
     */
    function getPYTHUnsafe(address base)
        external
        view
        returns (uint256 price, uint256 publishTime)
    {
        bytes32 feedId = priceFeedId[base];
        require(feedId != bytes32(0), "No feed");

        PythStructs.Price memory p = PYTH.getPriceUnsafe(feedId);
        require(p.price > 0, "Price <= 0");

        price = _normalizeTo1e8(p);
        publishTime = p.publishTime;
    }
}
