// SPDX-License-Identifier: MIT
// Envelop V2, wNFT implementation

pragma solidity ^0.8.28;

import "./WNFTV2Index.sol";
/**
 * @dev Envelop V2 mplementation of WNFT for INDEX for Events.
 * Only name and symbol are redefined.
 */

contract WNFTV2IndexForEvent01 is WNFTV2Index {
    constructor(address _defaultFactory) WNFTV2Index(_defaultFactory) {}

    function name() public pure override returns (string memory) {
        return "Envelop V2 Indices for Competition";
    }

    function symbol() public pure override returns (string memory) {
        return "Indices 2025";
    }
}
