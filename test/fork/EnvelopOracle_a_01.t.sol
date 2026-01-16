// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/utils/EnvelopOracle.sol";
import "../../src/utils/Predicter.sol";
import "./BaseForkTest.sol";

contract EnvelopOracle_fork_a_01 is BaseForkTest {
    EnvelopOracle internal oracle;

    address feedRegistry = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf;
    uint256 maxStale = 36000000000;
    address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address niftsy = 0x7728cd70b3dD86210e2bd321437F448231B81733;
    uint8 usdtDecimals = 8;

    function setUp() public {
        oracle = new EnvelopOracle(feedRegistry, maxStale);
    }

    function test_getPriceInUSD_success() public onlyOnFork {
        uint256 gotPrice = oracle.getPriceInUSD(usdt);
        assertApproxEqAbs(gotPrice, 10**usdtDecimals, 10**(usdtDecimals - 2));
    }

    function test_getPriceInUSD_nonPricableToken() public onlyOnFork {
        vm.expectRevert("Feed not found");
        oracle.getPriceInUSD(niftsy);
    }

    function test_getPriceInUSDWithMeta() public onlyOnFork {
        (uint256 priceUsd, uint80 roundId, uint256 updatedAt, uint8 decimals) = oracle.getPriceInUSDWithMeta(usdt);
        assertApproxEqAbs(priceUsd, 10**usdtDecimals, 10**(usdtDecimals - 2));
        assertGt(roundId, 0);
        assertGt(updatedAt, 0);
        assertEq(decimals, usdtDecimals);
    }      

    function test_getPriceInUSDWithMeta_nonPricableToken() public onlyOnFork {
        vm.expectRevert("Feed not found");
        oracle.getPriceInUSDWithMeta(niftsy);
    }    

    function test_getIndexPrice_success() public onlyOnFork {
        CompactAsset[] memory assets = new CompactAsset[](2);
        assets[0] = CompactAsset({token: usdt, amount: 1});
        assets[1] = CompactAsset({token: dai, amount: 1});
        uint256 actualPrice = oracle.getIndexPrice(assets);
        assertApproxEqAbs(actualPrice, 2 * 10**usdtDecimals, 10**(usdtDecimals - 2));
    }

    function test_getIndexPrice_nonPricableToken() public onlyOnFork {
        CompactAsset[] memory assets = new CompactAsset[](2);
        assets[0] = CompactAsset({token: usdt, amount: 1});
        assets[1] = CompactAsset({token: niftsy, amount: 1});
        vm.expectRevert("Feed not found");
        oracle.getIndexPrice(assets);
    }  
}