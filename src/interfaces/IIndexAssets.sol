// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IEnvelopOracle.sol";

/// @notice Callback interface implemented by WNFTV2SmartIndex.
/// EnvelopOracle calls these to pull portfolio data without storing assets itself.
interface IIndexAssets {
    /// @notice Returns the fixed portfolio of the index
    function getIndexAssets() external view returns (CompactAsset[] memory);

    /// @notice Returns the IAMMPriceAdapter address; address(0) = use Chainlink
    function getIndexAmm() external view returns (address);

    /// @notice Returns the base token for AMM pricing (e.g. USDC, WETH); address(0) = USD
    function getIndexBaseAsset() external view returns (address);
}
