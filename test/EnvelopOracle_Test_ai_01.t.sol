// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EnvelopOracle, FeedRegistryInterface} from "../src/utils/EnvelopOracle.sol";
import "../src/interfaces/IEnvelopOracle.sol";

contract MockFeedRegistry is FeedRegistryInterface {
    struct FeedData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
        uint8 decimals;
        bool exists;
    }

    // base => quote => feed
    mapping(address => mapping(address => FeedData)) public feeds;

    function setFeed(
        address base,
        address quote,
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound,
        uint8 dec
    ) external {
        feeds[base][quote] = FeedData({
            roundId: roundId,
            answer: answer,
            startedAt: startedAt,
            updatedAt: updatedAt,
            answeredInRound: answeredInRound,
            decimals: dec,
            exists: true
        });
    }

    function latestRoundData(address base, address quote)
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        FeedData memory f = feeds[base][quote];
        require(f.exists, "NO_FEED");
        return (f.roundId, f.answer, f.startedAt, f.updatedAt, f.answeredInRound);
    }

    function decimals(address base, address quote) external view returns (uint8) {
        FeedData memory f = feeds[base][quote];
        require(f.exists, "NO_FEED");
        return f.decimals;
    }
}

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

contract EnvelopOracle_Test_ai_01 is Test {
    // reuse constants from the contract for clarity
    address constant USD = 0x0000000000000000000000000000000000000348;
    address constant ETH_BASE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    MockFeedRegistry reg;
    EnvelopOracle oracle;

    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    // We'll use mock tokens to control decimals.
    MockERC20Decimals usdcLike; // 6 decimals
    MockERC20Decimals daiLike;  // 18 decimals

    function setUp() public {
        reg = new MockFeedRegistry();

        // deploy oracle as this test contract (owner = address(this))
        oracle = new EnvelopOracle(address(reg), 1 days);

        usdcLike = new MockERC20Decimals("USD Coin", "USDC", 6);
        daiLike  = new MockERC20Decimals("Dai Stablecoin", "DAI", 18);
        


        // Set feed prices in "answer" units (your oracle currently returns raw answer, "Normalize to 1e8" per comment)
        // Let's assume:
        // ETH/USD = 2,000 * 1e8
        // USDC/USD = 1 * 1e8
        // DAI/USD = 1 * 1e8
        vm.warp(1234455666);
        reg.setFeed(address(usdcLike), USD, 10, int256(1e8),   block.timestamp - 10, block.timestamp - 5, 10, 8);
        reg.setFeed(address(daiLike),  USD, 11, int256(1e8),   block.timestamp - 10, block.timestamp - 5, 11, 8);
        reg.setFeed(ETH_BASE,         USD, 12, int256(2000e8), block.timestamp - 10, block.timestamp - 5, 12, 8);
    }

    function test_getPriceInUSD_basic() public view {
        uint256 p = oracle.getPriceInUSD(address(usdcLike));
        assertEq(p, 1e8);
    }

    function test_getPriceInUSDWithMeta() public view {
        (uint256 p, uint80 rid, uint256 updatedAt, uint8 dec) =
            oracle.getPriceInUSDWithMeta(address(daiLike));

        assertEq(p, 1e8);
        assertEq(rid, 11);
        assertEq(dec, 8);
        assertGt(updatedAt, 0);
    }

    function test_getPriceInUSD_revertsOnNonPositiveAnswer() public {
        // overwrite feed with answer <= 0
        reg.setFeed(address(usdcLike), USD, 20, int256(0), 0, block.timestamp, 20, 8);

        vm.expectRevert(bytes("Price <= 0"));
        oracle.getPriceInUSD(address(usdcLike));
    }

    function test_getPriceInUSD_revertsOnAnsweredInRoundLtRoundId() public {
        reg.setFeed(address(usdcLike), USD, 30, int256(1e8), 0, block.timestamp, 29, 8);

        vm.expectRevert(bytes("Stale answer"));
        oracle.getPriceInUSD(address(usdcLike));
    }

    function test_overrideIndexPrice_onlyOwner() public {
        // non-owner
        vm.prank(alice);
        vm.expectRevert(); // OZ Ownable revert selector differs by version; no need to hardcode
        oracle.overrideIndexPrice(address(0x1234), 123);

        // owner (this test contract)
        oracle.overrideIndexPrice(address(0x1234), 123);
        assertEq(oracle.getIndexPrice(address(0x1234)), 123);
    }

    function test_overrideIndexPrice_revertsOnZero() public {
        vm.expectRevert(bytes("Price <= 0"));
        oracle.overrideIndexPrice(address(0x1234), 0);
    }

    function test_getIndexPrice_assets_erc20Decimals() public view {
        // total = amount * price / 10**tokenDecimals
        // Use 2 USDC (6 decimals): amount = 2_000000
        // price = 1e8
        // total = 2e6 * 1e8 / 1e6 = 2e8
        CompactAsset[] memory a = new CompactAsset[](1);
        a[0] = CompactAsset({token: address(usdcLike), amount: 2_000000});

        uint256 total = oracle.getIndexPrice(a);
        assertEq(total, 2e8);
    }

    function test_getIndexPrice_assets_ethBase() public view {
        // total = amount * price / 1e18
        // Use 0.5 ETH: amount = 0.5e18
        // price = 2000e8
        // total = 0.5e18 * 2000e8 / 1e18 = 1000e8
        CompactAsset[] memory a = new CompactAsset[](1);
        a[0] = CompactAsset({token: ETH_BASE, amount: uint96(0.5 ether)});

        uint256 total = oracle.getIndexPrice(a);
        assertEq(total, 1000e8);
    }

    function test_getIndexPrice_assets_mixed() public view {
        // 1 ETH + 10 USDC
        // ETH = 2000e8
        // 10 USDC => amount 10e6 => 10e6 * 1e8 / 1e6 = 10e8
        // total = 2010e8
        CompactAsset[] memory a = new CompactAsset[](2);
        a[0] = CompactAsset({token: ETH_BASE, amount: uint96(1 ether)});
        a[1] = CompactAsset({token: address(usdcLike), amount: 10_000000});

        uint256 total = oracle.getIndexPrice(a);
        assertEq(total, 2010e8);
    }
}