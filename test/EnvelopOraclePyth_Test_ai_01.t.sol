// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EnvelopOraclePyth} from "../src/utils/EnvelopOraclePyth.sol";
import {IEnvelopOracle, CompactAsset} from "../src/interfaces/IEnvelopOracle.sol";
import {MockPyth} from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";
import {PythErrors} from "@pythnetwork/pyth-sdk-solidity/PythErrors.sol";

/// @dev Minimal token stub — only name/symbol/decimals needed for oracle tests.
contract MockERC20Decimals {
    string internal _name;
    string internal _symbol;
    uint8 internal _dec;

    constructor(string memory n, string memory s, uint8 d) {
        _name = n;
        _symbol = s;
        _dec = d;
    }

    function name() external view returns (string memory) { return _name; }
    function symbol() external view returns (string memory) { return _symbol; }
    function decimals() external view returns (uint8) { return _dec; }
}

contract EnvelopOraclePyth_Test_ai_01 is Test {
    address constant ETH_BASE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Synthetic feed ids — values don't matter for MockPyth, only uniqueness.
    bytes32 constant FEED_USDC = bytes32(uint256(0x01));
    bytes32 constant FEED_DAI  = bytes32(uint256(0x02));
    bytes32 constant FEED_ETH  = bytes32(uint256(0x03));
    bytes32 constant FEED_NEG  = bytes32(uint256(0x04));
    bytes32 constant FEED_E6   = bytes32(uint256(0x05));
    bytes32 constant FEED_E10  = bytes32(uint256(0x06));

    MockPyth internal pyth;
    EnvelopOraclePyth internal oracle;

    MockERC20Decimals internal usdcLike; // 6 decimals
    MockERC20Decimals internal daiLike;  // 18 decimals
    MockERC20Decimals internal tokenE6;
    MockERC20Decimals internal tokenE10;

    address internal alice = address(0xA11CE);

    uint256 internal constant MAX_STALE = 1 days;

    function setUp() public {
        // validTimePeriod = 1 day, singleUpdateFeeInWei = 1.
        pyth = new MockPyth(MAX_STALE, 1);

        oracle = new EnvelopOraclePyth(address(pyth), MAX_STALE);

        usdcLike = new MockERC20Decimals("USD Coin", "USDC", 6);
        daiLike  = new MockERC20Decimals("Dai Stablecoin", "DAI", 18);
        tokenE6  = new MockERC20Decimals("E6 Token", "E6", 18);
        tokenE10 = new MockERC20Decimals("E10 Token", "E10", 18);

        oracle.setFeedId(address(usdcLike), FEED_USDC);
        oracle.setFeedId(address(daiLike),  FEED_DAI);
        oracle.setFeedId(ETH_BASE,          FEED_ETH);
        oracle.setFeedId(address(tokenE6),  FEED_E6);
        oracle.setFeedId(address(tokenE10), FEED_E10);

        vm.warp(1_700_000_000);

        // Seed MockPyth with prices.
        // USDC = 1.00 USD (price 1e8, expo -8 → 1e8)
        _pushPrice(FEED_USDC, int64(1e8),   -8);
        // DAI  = 1.00 USD (price 1e8, expo -8 → 1e8)
        _pushPrice(FEED_DAI,  int64(1e8),   -8);
        // ETH  = 2000.00 USD (price 2000e8, expo -8 → 2000e8)
        _pushPrice(FEED_ETH,  int64(2000e8),-8);
        // E6   = price 12345.67, expo -6 → raw 12345670000, shift -2 → 1234567e2 = 123456700 = 1.234567e8
        _pushPrice(FEED_E6,   int64(12345670000), -6);
        // E10  = price 123456789012, expo -10 → shift +2 → 123456789012 / 100 = 1234567890 = 12.34567890e8
        _pushPrice(FEED_E10,  int64(123456789012), -10);
    }

    function _pushPrice(bytes32 id, int64 price, int32 expo) internal {
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = pyth.createPriceFeedUpdateData(
            id,
            price,
            uint64(uint64(price > 0 ? price : -price) / 100), // dummy conf
            expo,
            price,
            uint64(uint64(price > 0 ? price : -price) / 100),
            uint64(block.timestamp)
        );
        uint256 fee = pyth.getUpdateFee(updateData);
        pyth.updatePriceFeeds{value: fee}(updateData);
    }

    receive() external payable {}

    // -------- price normalization --------

    function test_getPriceInUSD_basic_expoNeg8() public view {
        assertEq(oracle.getPriceInUSD(address(usdcLike)), 1e8);
        assertEq(oracle.getPriceInUSD(address(daiLike)),  1e8);
        assertEq(oracle.getPriceInUSD(ETH_BASE),          2000e8);
    }

    function test_getPriceInUSD_expoNeg6_divides() public view {
        // expo = -6 means raw is already in 1e6 units → to 1e8 we multiply by 100 if shift>=0.
        // shift = expo - (-8) = -6 - (-8) = +2 → multiply by 10^2.
        // raw = 12345670000 * 100 = 1234567000000 — that's huge. Let me check.
        // Actually our seed: price=12345670000, expo=-6 → real value 12345.67 USD.
        // Normalize to 1e8: 12345.67 * 1e8 = 1234567000000 — yes, this is correct.
        // (overflows? int64 max ≈ 9.2e18, 12345.67e8 = 1.23e12 — fine.)
        assertEq(oracle.getPriceInUSD(address(tokenE6)), 1234567000000);
    }

    function test_getPriceInUSD_expoNeg10_divides() public view {
        // shift = -10 - (-8) = -2 → divide by 100.
        // raw = 123456789012 / 100 = 1234567890 = 12.3456789 USD → 12.3456789e8.
        assertEq(oracle.getPriceInUSD(address(tokenE10)), 1234567890);
    }

    function test_getPriceInUSDWithMeta_pythSemantics() public view {
        (uint256 p, uint80 rid, uint256 updatedAt, uint8 dec) =
            oracle.getPriceInUSDWithMeta(address(usdcLike));

        assertEq(p, 1e8);
        assertEq(rid, 0);                  // Pyth has no rounds
        assertEq(dec, 8);
        assertEq(updatedAt, block.timestamp); // publishTime
    }

    // -------- failure modes --------

    function test_getPriceInUSD_revertsOnNoFeed() public {
        MockERC20Decimals unmapped = new MockERC20Decimals("NoFeed", "NF", 18);

        vm.expectRevert(bytes("No feed"));
        oracle.getPriceInUSD(address(unmapped));
    }

    function test_getPriceInUSD_revertsOnNegativePrice() public {
        // Push a non-positive price for a brand-new feed.
        oracle.setFeedId(address(tokenE6), FEED_NEG);
        _pushPrice(FEED_NEG, int64(0), -8);

        vm.expectRevert(bytes("Price <= 0"));
        oracle.getPriceInUSD(address(tokenE6));
    }

    function test_getPriceInUSD_revertsOnStale() public {
        vm.warp(block.timestamp + MAX_STALE + 1);

        vm.expectRevert(PythErrors.StalePrice.selector);
        oracle.getPriceInUSD(address(usdcLike));
    }

    // -------- getPYTHUnsafe (price + time, no staleness check) --------

    function test_getPYTHUnsafe_returnsPriceAndTime() public view {
        (uint256 price, uint256 publishTime) = oracle.getPYTHUnsafe(address(usdcLike));
        assertEq(price, 1e8);
        assertEq(publishTime, block.timestamp); // publishTime seeded in setUp
    }

    function test_getPYTHUnsafe_ignoresStale() public {
        uint256 seededAt = block.timestamp;

        // Move far past MAX_STALE: the staleness-checked path must revert...
        vm.warp(block.timestamp + MAX_STALE + 1);
        vm.expectRevert(PythErrors.StalePrice.selector);
        oracle.getPriceInUSD(address(usdcLike));

        // ...but the unsafe getter still returns the (now stale) price and its original publishTime.
        (uint256 price, uint256 publishTime) = oracle.getPYTHUnsafe(address(usdcLike));
        assertEq(price, 1e8);
        assertEq(publishTime, seededAt);
    }

    function test_getPYTHUnsafe_expoNormalization() public view {
        // Shares _normalizeTo1e8 with getPriceInUSD → must match for non -8 exponents.
        (uint256 p6,)  = oracle.getPYTHUnsafe(address(tokenE6));
        (uint256 p10,) = oracle.getPYTHUnsafe(address(tokenE10));
        assertEq(p6,  oracle.getPriceInUSD(address(tokenE6)));
        assertEq(p10, oracle.getPriceInUSD(address(tokenE10)));
        assertEq(p6,  1234567000000);
        assertEq(p10, 1234567890);
    }

    function test_getPYTHUnsafe_revertsOnNoFeed() public {
        MockERC20Decimals unmapped = new MockERC20Decimals("NoFeed", "NF", 18);

        vm.expectRevert(bytes("No feed"));
        oracle.getPYTHUnsafe(address(unmapped));
    }

    function test_getPYTHUnsafe_revertsOnNegativePrice() public {
        oracle.setFeedId(address(tokenE6), FEED_NEG);
        _pushPrice(FEED_NEG, int64(0), -8);

        vm.expectRevert(bytes("Price <= 0"));
        oracle.getPYTHUnsafe(address(tokenE6));
    }

    // -------- admin --------

    function test_setFeedId_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(); // OZ Ownable
        oracle.setFeedId(address(usdcLike), bytes32(uint256(0x99)));
    }

    function test_setFeedIdBatch_lenMismatch() public {
        address[] memory tokens = new address[](2);
        bytes32[] memory feeds  = new bytes32[](1);
        tokens[0] = address(usdcLike);
        tokens[1] = address(daiLike);
        feeds[0]  = bytes32(uint256(0x99));

        vm.expectRevert(bytes("len mismatch"));
        oracle.setFeedIdBatch(tokens, feeds);
    }

    function test_setFeedIdBatch_setsAll() public {
        address[] memory tokens = new address[](2);
        bytes32[] memory feeds  = new bytes32[](2);
        tokens[0] = address(0x111); feeds[0] = bytes32(uint256(0xaa));
        tokens[1] = address(0x222); feeds[1] = bytes32(uint256(0xbb));

        oracle.setFeedIdBatch(tokens, feeds);
        assertEq(oracle.priceFeedId(address(0x111)), bytes32(uint256(0xaa)));
        assertEq(oracle.priceFeedId(address(0x222)), bytes32(uint256(0xbb)));
    }

    // -------- IEnvelopOracle override path --------

    function test_overrideIndexPrice_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(); // OZ Ownable
        oracle.overrideIndexPrice(address(0x1234), 123);

        oracle.overrideIndexPrice(address(0x1234), 123);
        assertEq(oracle.getIndexPrice(address(0x1234)), 123);
    }

    function test_overrideIndexPrice_revertsOnZero() public {
        vm.expectRevert(bytes("Price <= 0"));
        oracle.overrideIndexPrice(address(0x1234), 0);
    }

    // -------- getIndexPrice(CompactAsset[]) --------

    function test_getIndexPrice_assets_erc20Decimals() public view {
        // 2 USDC, 6 decimals, $1 each → 2 * 1e8.
        CompactAsset[] memory a = new CompactAsset[](1);
        a[0] = CompactAsset({token: address(usdcLike), amount: 2_000000});

        assertEq(oracle.getIndexPrice(a), 2e8);
    }

    function test_getIndexPrice_assets_ethBase() public view {
        // 0.5 ETH @ $2000 → $1000 → 1000e8.
        CompactAsset[] memory a = new CompactAsset[](1);
        a[0] = CompactAsset({token: ETH_BASE, amount: uint96(0.5 ether)});

        assertEq(oracle.getIndexPrice(a), 1000e8);
    }

    function test_getIndexPrice_assets_mixed() public view {
        // 1 ETH + 10 USDC → $2000 + $10 = $2010 → 2010e8.
        CompactAsset[] memory a = new CompactAsset[](2);
        a[0] = CompactAsset({token: ETH_BASE, amount: uint96(1 ether)});
        a[1] = CompactAsset({token: address(usdcLike), amount: 10_000000});

        assertEq(oracle.getIndexPrice(a), 2010e8);
    }
}
