// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-lint: disable-next-line(unaliased-plain-import)
import "../interfaces/IEnvelopOracle.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// interface IEnvelopOracle {
//     function getIndexPrice(address _v2Index) external view returns (uint256);
//     function getIndexPrice(CompactAsset[] calldata _assets) external view returns (uint256);
// }
// ---- Chainlink Feed Registry minimal interface ----
interface FeedRegistryInterface {
    function latestRoundData(address base, address quote)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function decimals(address base, address quote) external view returns (uint8);
}

contract EnvelopOracle is IEnvelopOracle, Ownable {
    // =========================================================
    //                     Price Oracle part
    // =========================================================

    /// @notice Chainlink Feed Registry
    FeedRegistryInterface public immutable FEED_REGISTRY;

    /// @notice USD denomination address for Feed Registry (not an ERC20)
    /// @dev Chainlink uses a special pseudo-address for USD denomination.
    address public constant DENOMINATION_USD = 0x0000000000000000000000000000000000000348;

    /// @notice Maximum allowed staleness for a price feed, in seconds
    uint256 public immutable MAX_STALE;

    // =========================================================
    //                         Events
    // =========================================================

    mapping(address object => uint256 overrided) public overridedPrices;

    /// @notice Emitted when price is successfully read from Feed Registry.
    event PriceRead(address indexed base, uint256 priceUsd, uint80 roundId, uint256 updatedAt);

    // =========================================================
    //                        Constructor
    // =========================================================

    /**
     * @param _feedRegistry Address of Chainlink Feed Registry (or adapter).
     * @param _maxStale Maximum allowed staleness for a price (seconds).
     */
    constructor(address _feedRegistry, uint256 _maxStale) Ownable(msg.sender) {
        FEED_REGISTRY = FeedRegistryInterface(_feedRegistry);
        MAX_STALE = _maxStale;
    }

    // =========================================================
    //                    Public price helpers
    // =========================================================

    /**
     * @notice Get latest price for a base asset in USD, normalized to 1e18.
     * @param base Asset address (e.g., token address) to query.
     * @return priceUsd Latest price in 1e18 decimals.
     */
    function getPriceInUSD(address base) public view returns (uint256 priceUsd) {
        (priceUsd,,,) = _getLatestPriceInUSD(base);
    }

    /**
     * @notice Get latest price + metadata for a base asset in USD.
     * @param base Asset address to query.
     * @return priceUsd Latest price in 1e18 decimals.
     * @return roundId Feed round ID used.
     * @return updatedAt Timestamp when the feed was updated.
     */
    function getPriceInUSDWithMeta(address base)
        external
        view
        returns (uint256 priceUsd, uint80 roundId, uint256 updatedAt, uint8 decimals)
    {
        return _getLatestPriceInUSD(base);
    }

    function getIndexPrice(address _v2Index) external view returns (uint256) {
        return overridedPrices[_v2Index];
    }

    function getIndexPrice(CompactAsset[] calldata _assets) external view returns (uint256 total) {
        for (uint256 i = 0; i < _assets.length; i++) {
            total += _assets[i].amount * getPriceInUSD(_assets[i].token);
        }
    }

    function overrideIndexPrice(address _v2Index, uint256 _price) external onlyOwner {
        require(_price > 0, "Price <= 0");
        overridedPrices[_v2Index] = _price;
    }

    // =========================================================
    //                     Internal price helper
    // =========================================================

    /**
     * @dev Internal helper to fetch and normalize USD price from Feed Registry.
     * @param base Asset address to query.
     * @return priceUsd Price
     * @return roundId Chainlink feed round ID used.
     * @return updatedAt Timestamp when feed was updated.
     * @return dec decimals
     */
    function _getLatestPriceInUSD(address base)
        internal
        view
        returns (uint256 priceUsd, uint80 roundId, uint256 updatedAt, uint8 dec)
    {
        (uint80 _roundId, int256 answer,, uint256 _updatedAt, uint80 answeredInRound) =
            FEED_REGISTRY.latestRoundData(base, DENOMINATION_USD);

        require(answer > 0, "Price <= 0");
        require(answeredInRound >= _roundId, "Stale answer");
        require(_updatedAt + MAX_STALE >= block.timestamp, "Price is stale");

        dec = FEED_REGISTRY.decimals(base, DENOMINATION_USD);

        // Normalize to 1e18
        priceUsd = uint256(answer);
        roundId = _roundId;
        updatedAt = _updatedAt;
    }
}
