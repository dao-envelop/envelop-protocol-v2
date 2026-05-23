// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// forge-lint: disable-next-line(unaliased-plain-import)
import "../interfaces/IEnvelopOracle.sol";
import "../interfaces/IIndexAssets.sol";
import "../interfaces/IAMMPriceAdapter.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

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
    address public constant ETH_BASE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @notice Maximum allowed staleness for a price feed, in seconds
    uint256 public immutable MAX_STALE;

    // =========================================================
    //                    Index registry
    // =========================================================

    mapping(address wNFT => uint256 price)   public overridedPrices;
    mapping(address wNFT => bool)            public isRegistered;
    mapping(address wNFT => address updater) public authorizedUpdater;

    // =========================================================
    //                         Events
    // =========================================================

    /// @notice Emitted when price is successfully read from Feed Registry.
    event PriceRead(address indexed base, uint256 priceUsd, uint80 roundId, uint256 updatedAt);

    event EnvelopIndexRegistered(address indexed wNFT);
    event EnvelopIndexDeregistered(address indexed wNFT);
    event EnvelopIndexPriceSet(address indexed wNFT, uint256 price, address indexed setter);

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
     * @notice Get latest price for a base asset in USD, normalized to 1e8.
     * @param base Asset address (e.g., token address) to query.
     * @return priceUsd Latest price in 1e8 decimals.
     */
    function getPriceInUSD(address base) public view returns (uint256 priceUsd) {
        (priceUsd,,,) = _getLatestPriceInUSD(base);
    }

    /**
     * @notice Get latest price + metadata for a base asset in USD.
     * @param base Asset address to query.
     * @return priceUsd Latest price in 1e8 decimals.
     * @return roundId Feed round ID used.
     * @return updatedAt Timestamp when the feed was updated.
     * @return decimals Feed decimals.
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

        // 2. Auto-compute via callback
        if (isRegistered[_v2Index]) {
            CompactAsset[] memory assets   = IIndexAssets(_v2Index).getIndexAssets();
            address amm                    = IIndexAssets(_v2Index).getIndexAmm();
            address baseAsset              = IIndexAssets(_v2Index).getIndexBaseAsset();
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
                    (uint256 unitPrice,,,) = _getLatestPriceInUSD(assets[i].token); // 1e8
                    total += unitPrice * uint256(assets[i].amount) / (10 ** uint256(tokenDec));
                }
            }
            return total;
        }

        return 0;
    }

    function getIndexPrice(CompactAsset[] calldata _assets) external view returns (uint256 total) {
        for (uint256 i = 0; i < _assets.length; i++) {
            if (_assets[i].token != ETH_BASE) {
                total += (_assets[i].amount * getPriceInUSD(_assets[i].token))
                  / 10**IERC20Metadata(_assets[i].token).decimals();
            } else {
                total += _assets[i].amount * getPriceInUSD(_assets[i].token)
                  / 10**18;
            }
        }
    }

    // =========================================================
    //               IEnvelopOracle — index registry
    // =========================================================

    /**
     * @notice Register the calling wNFT as a tracked index.
     * Caller must implement IIndexAssets (validated via ERC-165).
     */
    function registerIndex() external {
        require(
            IERC165(msg.sender).supportsInterface(type(IIndexAssets).interfaceId),
            "Not IIndexAssets"
        );
        isRegistered[msg.sender] = true;
        emit EnvelopIndexRegistered(msg.sender);
    }

    /**
     * @notice Deregister the calling wNFT. Called via _beforeUnwrap.
     */
    function deregisterIndex() external {
        require(isRegistered[msg.sender], "Not registered");
        isRegistered[msg.sender] = false;
        emit EnvelopIndexDeregistered(msg.sender);
    }

    /**
     * @notice Authorize an updater (e.g. Predicter) to set prices for this wNFT.
     * Must be called by the wNFT itself (via WNFTV2SmartIndex.setIndexUpdater).
     */
    function setIndexUpdater(address _wNFT, address _updater) external {
        require(msg.sender == _wNFT, "Only wNFT itself");
        authorizedUpdater[_wNFT] = _updater;
    }

    /**
     * @notice Set a manual price override for a registered index.
     * Callable by the authorized updater or owner.
     */
    function setIndexPrice(address _wNFT, uint256 _price) external {
        require(
            msg.sender == authorizedUpdater[_wNFT] || msg.sender == owner(),
            "Not authorized"
        );
        overridedPrices[_wNFT] = _price;
        emit EnvelopIndexPriceSet(_wNFT, _price, msg.sender);
    }

    // =========================================================
    //               Legacy owner price override
    // =========================================================

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
     * @return priceUsd Price in 1e8 decimals.
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
        // forge-lint: disable-next-line(block-timestamp) - staleness window vs Chainlink updatedAt; intentional time comparison.
        require(_updatedAt + MAX_STALE >= block.timestamp, "Price is stale");

        dec = FEED_REGISTRY.decimals(base, DENOMINATION_USD);

        // Already in feed's native decimals (typically 8); callers normalize as needed
        priceUsd = SafeCast.toUint256(answer);
        roundId = _roundId;
        updatedAt = _updatedAt;
    }
}
