// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @dev Adapter interface for AMM-based price sources.
/// Concrete adapters (UniswapV3Adapter, CurveAdapter, etc.) are deployed separately.
/// The adapter address is set as immutable AMM_ADAPTER in the WNFTV2SmartIndex constructor.
/// Each AMM requires a separate implementation deployment; the factory creates proxies from it.
interface IAMMPriceAdapter {
    /// @dev Returns USD value of `amount` units of `token` via the AMM.
    /// @param token     ERC20 token address
    /// @param amount    Token amount in native units (same as CompactAsset.amount)
    /// @param baseAsset Intermediate token in the AMM pair (e.g. USDC, WETH).
    ///                  Adapter resolves baseAsset -> USD internally.
    /// @return price    USD value
    /// @return decimals Price decimals (may differ from Chainlink's 8)
    ///
    /// @notice MUST return a TWAP (time-weighted average price) with a minimum
    /// window of 30 minutes — NOT a spot price. Spot-price adapters are vulnerable
    /// to flash-loan manipulation at fixIndex time and are prohibited.
    function getTokenPriceUSD(address token, uint96 amount, address baseAsset)
        external view returns (uint256 price, uint8 decimals);
}
