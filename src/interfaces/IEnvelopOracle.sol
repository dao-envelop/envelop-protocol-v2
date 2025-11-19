// SPDX-License-Identifier: MIT
// ENVELOP(NIFTSY) protocol V2 for NFT. Onchain Oracle
pragma solidity ^0.8.28;

struct CompactAsset {
    address token; // 20 byte
    uint96 amount; // 12 byte
}

interface IEnvelopOracle {
    function getIndexPrice(address _v2Index) external returns(uint256);
    function getIndexPrice(CompactAsset[] calldata _assets) external returns(uint256);

}
