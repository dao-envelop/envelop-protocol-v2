// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/utils/EnvelopOracle.sol";

contract EnvelopOracle_a_01 is Test {
    EnvelopOracle internal oracle;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);
    address feedRegistry = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf;
    uint256 maxStale = 36000000000;
    

    function setUp() public {
        oracle = new EnvelopOracle(feedRegistry, maxStale);
    }

    // ------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------


    function test_call() public {
        uint256 price1 = oracle.getPriceInUSD(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        (uint256 priceUsd, uint80 roundId, uint256 updatedAt, uint8 decimals) = oracle.getPriceInUSDWithMeta(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        console2.log(price1);
        console2.log(priceUsd);
        console2.log(roundId);
        console2.log(updatedAt);
        console2.log(decimals);
    }
}