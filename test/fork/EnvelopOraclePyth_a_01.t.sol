// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EnvelopOraclePyth} from "../../src/utils/EnvelopOraclePyth.sol";
import {IEnvelopOracle, CompactAsset} from "../../src/interfaces/IEnvelopOracle.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "./BaseForkTest.sol";

/// @notice Fork-test against the live Pyth contract on Ethereum mainnet.
/// @dev Pyth on mainnet stores price updates with publishTime close to the chain head, but
///      forge's --fork-url snapshot can be older than MAX_STALE. To remain self-contained,
///      this test computes MAX_STALE dynamically as `now - oldestPublishTime + buffer` so
///      that getPriceNoOlderThan does not revert just because the fork block is "old".
///
///      run: forge test --match-contract EnvelopOraclePyth_fork_a_01 --rpc-url mainnet -vv
contract EnvelopOraclePyth_fork_a_01 is BaseForkTest {
    address constant PYTH_ETH = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;

    // NOTE: Pyth on Ethereum mainnet is a pull oracle — feeds only exist on-chain after
    // someone has pushed an update VAA. This fork test uses the subset of v1 feeds that
    // are currently kept warm on mainnet (ETH, WBTC, UNI, LINK). The full 35-feed list
    // works against any chain where consumers (Predicter / the dApp itself) push updates
    // through `updateAndGetIndexPrice`.
    address constant ETH_BASE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant WBTC     = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant UNI      = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant LINK     = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    bytes32 constant FEED_ETH    = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
    bytes32 constant FEED_WBTC   = 0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33;
    bytes32 constant FEED_UNI    = 0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501;
    bytes32 constant FEED_LINK   = 0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221;

    EnvelopOraclePyth internal oracle;
    uint256 internal maxStale;

    function setUp() public {
        if (block.chainid == 31337) return; // local — onlyOnFork in tests will skip

        // Compute a maxStale large enough to read all relevant feeds on this fork block.
        // Walk the relevant feeds, take the oldest publishTime, add a 60s buffer.
        maxStale = _computeStaleWindow();

        oracle = new EnvelopOraclePyth(PYTH_ETH, maxStale);

        address[] memory tokens = new address[](4);
        bytes32[] memory feeds  = new bytes32[](4);
        tokens[0] = ETH_BASE; feeds[0] = FEED_ETH;
        tokens[1] = WBTC;     feeds[1] = FEED_WBTC;
        tokens[2] = UNI;      feeds[2] = FEED_UNI;
        tokens[3] = LINK;     feeds[3] = FEED_LINK;
        oracle.setFeedIdBatch(tokens, feeds);
    }

    function _computeStaleWindow() internal view returns (uint256) {
        bytes32[4] memory ids = [FEED_ETH, FEED_WBTC, FEED_UNI, FEED_LINK];
        uint256 oldest = block.timestamp;
        for (uint256 i; i < ids.length; ++i) {
            PythStructs.Price memory p = IPyth(PYTH_ETH).getPriceUnsafe(ids[i]);
            if (p.publishTime < oldest) oldest = p.publishTime;
        }
        // +60s buffer; +1 if fork block is ahead of all updates.
        return block.timestamp - oldest + 60;
    }

    // -------- sanity ranges --------

    function test_getPriceInUSD_WBTC_inRange() public view onlyOnFork {
        uint256 p = oracle.getPriceInUSD(WBTC);
        assertGt(p, 10_000e8,  "WBTC price suspiciously low");
        assertLt(p, 500_000e8, "WBTC price suspiciously high");
    }

    function test_getPriceInUSD_ETH_inRange() public view onlyOnFork {
        uint256 p = oracle.getPriceInUSD(ETH_BASE);
        assertGt(p, 200e8,    "ETH price suspiciously low");
        assertLt(p, 20_000e8, "ETH price suspiciously high");
    }

    function test_getPriceInUSD_UNI_positive() public view onlyOnFork {
        assertGt(oracle.getPriceInUSD(UNI), 0);
    }

    function test_getPriceInUSD_LINK_positive() public view onlyOnFork {
        assertGt(oracle.getPriceInUSD(LINK), 0);
    }

    // -------- metadata --------

    function test_getPriceInUSDWithMeta_pythSemantics() public view onlyOnFork {
        (uint256 priceUsd, uint80 roundId, uint256 updatedAt, uint8 dec) =
            oracle.getPriceInUSDWithMeta(WBTC);
        assertGt(priceUsd, 0);
        assertEq(roundId, 0, "roundId must be 0 in Pyth variant");
        assertEq(dec, 8);
        assertGt(updatedAt, 0);
    }

    // -------- basket --------

    function test_getIndexPrice_assets_basket() public view onlyOnFork {
        CompactAsset[] memory a = new CompactAsset[](2);
        // 1e-5 WBTC (8 decimals) + 1 UNI (18 decimals)
        a[0] = CompactAsset({token: WBTC, amount: 10**3}); // 10^3 sat ≈ 0.00001 WBTC
        a[1] = CompactAsset({token: UNI,  amount: uint96(1 ether)});

        uint256 total = oracle.getIndexPrice(a);
        assertGt(total, 0);
    }

    // -------- failure modes --------

    function test_getPriceInUSD_revertsOnNoFeed() public onlyOnFork {
        // DAI is not configured.
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        vm.expectRevert(bytes("No feed"));
        oracle.getPriceInUSD(dai);
    }
}
/* forge test --match-contract EnvelopOraclePyth_fork_a_01 --rpc-url mainnet -vvvv */
