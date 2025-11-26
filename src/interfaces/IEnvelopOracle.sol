// SPDX-License-Identifier: MIT
// ENVELOP(NIFTSY) protocol V2 for NFT. Onchain Oracle
pragma solidity ^0.8.28;

/// @dev Compact representation of an ERC20 asset + amount.
/// Used both for strike configuration and as portfolio items for the oracle.
struct CompactAsset {
    address token; // ERC20 token address (20 bytes)
    uint96 amount; // Amount with token decimals (12 bytes)
}

/// @dev Oracle interface for retrieving index prices.
/// Supports:
/// - price by index address
/// - price by custom portfolio composition
interface IEnvelopOracle {
    function getIndexPrice(address _v2Index) external view returns (uint256);
    function getIndexPrice(CompactAsset[] calldata _assets) external view returns (uint256);
}
