// SPDX-License-Identifier: MIT
// Envelop V2 — Simple Price Oracle

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// forge-lint: disable-next-line(unaliased-plain-import)
import "../interfaces/IEnvelopOracle.sol";

//
// ==========================
// === Base Structures =====
// ==========================
// https://etherscan.io/address/0x47fb2585d2c56fe188d0e6ec628a38b74fceeedf/advanced#readContract

// struct CompactAsset {
//     address token; // ERC20 token address
//     uint96 amount; // raw token amount (token decimals)
// }

// interface IEnvelopOracle {
//     function getIndexPrice(address _v2Index) external view returns (uint256);
//     function getIndexPrice(CompactAsset[] calldata _assets) external view returns (uint256);
// }

/// @notice Interface that any V2 Index must implement to be usable by `getIndexPrice(address)`
interface IIndexPortfolio {
    function getPortfolio() external view returns (CompactAsset[] memory);
}

//
// =========================
// === Chainlink oracle ===
// =========================
//

interface IAggregatorV3 {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

//
// ==========================
// === 1inch oracle iface ===
// ==========================
//

interface IOneInchOracle {
    /**
     * @notice Get rate of srcToken → dstToken scaled by 1e18.
     */
    function getRate(
        address srcToken,
        address dstToken,
        bool useWrappers
    ) external view returns (uint256);
}

//
// ==========================
// === Uniswap V2 pair =====
// ==========================
//

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);

    function getReserves()
        external view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

//
// ======================================================
// ===================== ORACLE CONTRACT =================
// ======================================================
//

/**
 * @title EnvelopOracle
 * @notice Composite oracle for Envelop Indexes that aggregates pricing from:
 *         1. Manual override per token (highest priority)
 *         2. Chainlink price feeds
 *         3. 1inch on-chain oracle
 *         4. Uniswap V2 reserve-based spot price
 *
 * @dev All prices are normalized to 1e18 units of QUOTE_TOKEN.
 *      QUOTE_TOKEN is expected to be a stable asset (e.g., USDC/USDT/DAI).
 */
contract EnvelopOracle is IEnvelopOracle, Ownable {
    uint256 public constant PRICE_DECIMALS = 1e18;

    /// @notice Token used as the quote currency (all prices denominated in this token)
    address public immutable QUOTE_TOKEN;

    /// @notice Manual override price for token → QUOTE, scaled to 1e18
    mapping(address => uint256) public manualPrice;

    /// @notice Mapping of token → Chainlink aggregator for token/QUOTE
    mapping(address => IAggregatorV3) public chainlinkFeeds;

    /// @notice Optional 1inch oracle address
    address public oneInchOracle;

    /// @notice Mapping of token → UniswapV2 pair(token, QUOTE)
    mapping(address => address) public uniswapV2Pairs;

    // ============================
    // ========= Errors ===========
    // ============================

    error PriceNotAvailable(address token);
    error ZeroAddress();
    error InvalidFeed();
    error InvalidPair();

    // ============================
    // ======== Constructor =======
    // ============================

    /**
     * @param _quoteToken Address of QUOTE_TOKEN (e.g., USDC)
     */
    constructor(address _quoteToken) 
    Ownable(msg.sender)
    {
        if (_quoteToken == address(0)) revert ZeroAddress();
        QUOTE_TOKEN = _quoteToken;
    }

    // =====================================================
    // ============= Admin Configuration (Owner) ============
    // =====================================================

    /**
     * @notice Set manual price override for a token.
     * @param token ERC20 token address.
     * @param price Price of 1 token in QUOTE_TOKEN units, scaled by 1e18.
     */
    function setManualPrice(address token, uint256 price) external onlyOwner {
        manualPrice[token] = price;
    }

    /**
     * @notice Remove a manual price override.
     */
    function clearManualPrice(address token) external onlyOwner {
        manualPrice[token] = 0;
    }

    /**
     * @notice Assign a Chainlink price feed for a token.
     * @param token ERC20 token.
     * @param feed Chainlink aggregator address.
     */
    function setChainlinkFeed(address token, address feed) external onlyOwner {
        if (feed == address(0)) {
            chainlinkFeeds[token] = IAggregatorV3(address(0));
        } else {
            chainlinkFeeds[token] = IAggregatorV3(feed);
        }
    }

    /**
     * @notice Set 1inch oracle address.
     */
    function setOneInchOracle(address oracleAddr) external onlyOwner {
        oneInchOracle = oracleAddr;
    }

    /**
     * @notice Assign Uniswap V2 pair for token/QUOTE price.
     * @param token ERC20 token.
     * @param pair UniswapV2 pair address.
     */
    function setUniswapV2Pair(address token, address pair) external onlyOwner {
        if (pair == address(0)) {
            uniswapV2Pairs[token] = address(0);
            return;
        }

        // sanity check: pair must contain valid tokens
        address t0 = IUniswapV2Pair(pair).token0();
        address t1 = IUniswapV2Pair(pair).token1();
        if (t0 == address(0) || t1 == address(0)) revert InvalidPair();

        uniswapV2Pairs[token] = pair;
    }

    // =====================================================
    // ================ IEnvelopOracle API =================
    // =====================================================

    /**
     * @inheritdoc IEnvelopOracle
     * @dev Fetches portfolio from index contract and computes price.
     */
    function getIndexPrice(address _v2Index)
        external
        view
        override
        returns (uint256)
    {
        CompactAsset[] memory assets = IIndexPortfolio(_v2Index).getPortfolio();
        return _calcIndexPrice(assets);
    }

    /**
     * @inheritdoc IEnvelopOracle
     */
    function getIndexPrice(CompactAsset[] calldata _assets)
        external
        view
        override
        returns (uint256)
    {
        return _calcIndexPrice(_assets);
    }

    // =====================================================
    // ================= Internal Logic =====================
    // =====================================================

    /**
     * @notice Computes the total value of a portfolio of assets.
     * @param assets Array of CompactAsset items.
     * @return Total portfolio value in QUOTE_TOKEN units (scaled 1e18).
     */
    function _calcIndexPrice(CompactAsset[] memory assets)
        internal
        view
        returns (uint256)
    {
        uint256 totalValue = 0;

        for (uint256 i = 0; i < assets.length; i++) {
            CompactAsset memory a = assets[i];
            if (a.amount == 0) continue;

            uint256 price = _getTokenPriceInQuote(a.token);

            uint8 tokenDec = _getTokenDecimals(a.token);

            // Normalize amount into 18 decimals
            uint256 normalizedAmount =
                uint256(a.amount) * PRICE_DECIMALS / (10 ** tokenDec);

            // Value in quote units
            uint256 value =
                normalizedAmount * price / PRICE_DECIMALS;

            totalValue += value;
        }

        return totalValue;
    }

    /**
     * @notice Resolve price of token in QUOTE_TOKEN units.
     * @dev The resolution order:
     *      1. manual override
     *      2. Chainlink
     *      3. 1inch oracle
     *      4. Uniswap V2 reserves
     * @return Price scaled by 1e18.
     */
    function _getTokenPriceInQuote(address token)
        internal
        view
        returns (uint256)
    {
        // If token *is* the quote token → 1
        if (token == QUOTE_TOKEN) {
            return PRICE_DECIMALS;
        }

        // 1) Manual price override
        uint256 m = manualPrice[token];
        if (m > 0) {
            return m;
        }

        // 2) Chainlink feed
        IAggregatorV3 feed = chainlinkFeeds[token];
        if (address(feed) != address(0)) {
            (, int256 answer, , , ) = feed.latestRoundData();
            if (answer > 0) {
                uint8 feedDec = feed.decimals();
                return uint256(answer) * PRICE_DECIMALS / (10 ** feedDec);
            }
        }

        // 3) 1inch oracle
        if (oneInchOracle != address(0)) {
            uint256 rate =
                IOneInchOracle(oneInchOracle).getRate(token, QUOTE_TOKEN, true);
            if (rate > 0) return rate;
        }

        // 4) Uniswap V2 pair
        address pairAddr = uniswapV2Pairs[token];
        if (pairAddr != address(0)) {
            IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
            (uint112 r0, uint112 r1, ) = pair.getReserves();
            address t0 = pair.token0();
            address t1 = pair.token1();

            if (t0 == token && t1 == QUOTE_TOKEN && r0 > 0 && r1 > 0) {
                return uint256(r1) * PRICE_DECIMALS / uint256(r0);
            }
            if (t1 == token && t0 == QUOTE_TOKEN && r0 > 0 && r1 > 0) {
                return uint256(r0) * PRICE_DECIMALS / uint256(r1);
            }
        }

        revert PriceNotAvailable(token);
    }

    /**
     * @notice Returns decimals for an ERC20 token.
     * @dev Falls back to 18 if not available.
     */
    function _getTokenDecimals(address token) internal view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 dec) {
            return dec;
        } catch {
            return 18;
        }
    }
}
