// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IEnvelopOracle.sol";

/// @dev Mock oracle returning a configurable price.
contract MockOracle is IEnvelopOracle {
    uint256 public price;
    mapping(address => bool) public isRegistered;
    mapping(address => address) public authorizedUpdater;
    mapping(address => uint256) public overridedPrices;

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function getIndexPrice(address _v2Index) external view override returns (uint256) {
        if (overridedPrices[_v2Index] != 0) return overridedPrices[_v2Index];
        return 0;
    }

    function getIndexPrice(CompactAsset[] calldata) external view override returns (uint256) {
        return price;
    }

    function registerIndex() external  {
        isRegistered[msg.sender] = true;
    }

    function deregisterIndex() external  {
        isRegistered[msg.sender] = false;
    }

    function setIndexUpdater(address _wNFT, address _updater) external  {
        require(msg.sender == _wNFT, "Only wNFT itself");
        authorizedUpdater[_wNFT] = _updater;
    }

    function setIndexPrice(address _wNFT, uint256 _price) external  {
        overridedPrices[_wNFT] = _price;
    }
}
