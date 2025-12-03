// test/EnvelopOracle.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/utils/EnvelopOracle.sol";
import "../src/mock/MockFeedRegistry.sol";

// We repeat CompactAsset here for the test; layout must match the one in EnvelopOracle.
// struct CompactAsset {
//     address token;
//     uint96 amount;
// }

/// @dev Small testable extension to set override prices.
contract EnvelopOracleTestable is EnvelopOracle {
    constructor(address feedRegistry, uint256 maxStale)
        EnvelopOracle(feedRegistry, maxStale)
    {}

    function setOverridePrice(address indexAddr, uint256 price) external {
        overridedPrices[indexAddr] = price;
    }
}

contract EnvelopOracleTest is Test {
    MockFeedRegistry public registry;
    EnvelopOracleTestable public oracle;

    address constant TOKEN_A = address(0xA1);
    address constant TOKEN_B = address(0xB2);
    address constant INDEX_1 = address(0x9999);

    function setUp() public {
        registry = new MockFeedRegistry();

        // Let MAX_STALE = 1 day for tests
        oracle = new EnvelopOracleTestable(address(registry), 1 days);
    }

    function _setFeedSimple(
        address base,
        int256 answer,
        uint8 _decimals,
        uint256 updatedAt
    ) internal {
        registry.setFeed(
            base,
            oracle.DENOMINATION_USD(),
            answer,
            updatedAt - 10,      // startedAt
            updatedAt,
            10,                  // roundId
            10,                  // answeredInRound
            _decimals
        );
    }

    /// @notice Basic happy-path test for getPriceInUSD.
    function test_getPriceInUSD_ok() public {
        uint256 nowTs = 1_000_000;
        vm.warp(nowTs);

        // price = 1000, decimals = 8 (e.g. 1000 * 1e8 from Chainlink)
        _setFeedSimple(TOKEN_A, 1000e8, 8, nowTs - 60);

        uint256 price = oracle.getPriceInUSD(TOKEN_A);
        assertEq(price, 1000e8, "Price should equal raw answer");

        // Also check meta getter
        (uint256 price2, uint80 roundId, uint256 updatedAt, uint8 dec) =
            oracle.getPriceInUSDWithMeta(TOKEN_A);

        assertEq(price2, 1000e8);
        assertEq(roundId, 10);
        assertEq(updatedAt, nowTs - 60);
        assertEq(dec, 8);
    }

    /// @notice Price <= 0 should revert.
    function test_getPriceInUSD_revertPriceLE0() public {
        uint256 nowTs = 1_000_000;
        vm.warp(nowTs);

        _setFeedSimple(TOKEN_A, 0, 8, nowTs - 60);

        vm.expectRevert(bytes("Price <= 0"));
        oracle.getPriceInUSD(TOKEN_A);
    }

    /// @notice answeredInRound < roundId should revert ("Stale answer").
    function test_getPriceInUSD_revertStaleRound() public {
        uint256 nowTs = 1_000_000;
        vm.warp(nowTs);

        // roundId = 10, answeredInRound = 9 (set вручную)
        registry.setFeed(
            TOKEN_A,
            oracle.DENOMINATION_USD(),
            100e8,
            nowTs - 100,
            nowTs - 60,
            10,
            9,          // answeredInRound < roundId
            8
        );

        vm.expectRevert(bytes("Stale answer"));
        oracle.getPriceInUSD(TOKEN_A);
    }

    /// @notice If updatedAt too old, should revert "Price is stale".
    function test_getPriceInUSD_revertPriceTooStale() public {
        uint256 nowTs = 1_000_000;
        vm.warp(nowTs);

        // MAX_STALE = 1 days, so anything older than nowTs - 1 days - 1 should revert.
        uint256 tooOld = nowTs - 1 days - 1;

        _setFeedSimple(TOKEN_A, 100e8, 8, tooOld);

        vm.expectRevert(bytes("Price is stale"));
        oracle.getPriceInUSD(TOKEN_A);
    }

    /// @notice test getIndexPrice(CompactAsset[]) aggregating prices * amounts.
    function test_getIndexPrice_portfolio() public {
        uint256 nowTs = 1_000_000;
        vm.warp(nowTs);

        // For simplicity: decimals = 0, so answer interpreted as integer price.
        // TOKEN_A price = 10, TOKEN_B price = 5
        _setFeedSimple(TOKEN_A, 10, 0, nowTs - 60);
        _setFeedSimple(TOKEN_B, 5, 0, nowTs - 60);

        CompactAsset[] memory assets = new CompactAsset[](2);
        assets[0] = CompactAsset({token: TOKEN_A, amount: 2}); // 2 * 10 = 20
        assets[1] = CompactAsset({token: TOKEN_B, amount: 3}); // 3 * 5 = 15

        uint256 total = oracle.getIndexPrice(assets);
        assertEq(total, 35, "Index price should be 35");
    }

    /// @notice test getIndexPrice(address) reading from overridden mapping.
    function test_getIndexPrice_override() public {
        oracle.setOverridePrice(INDEX_1, 12345);

        uint256 price = oracle.getIndexPrice(INDEX_1);
        assertEq(price, 12345);
    }
}
