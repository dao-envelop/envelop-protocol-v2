// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/utils/Predicter.sol";
import "../../src/utils/EnvelopOraclePyth.sol";
import "../../src/mock/MockERC20.sol";
import "./BaseForkTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PredicterTest_a_fork_3 is BaseForkTest  {
    MockERC20 internal mock;
    EnvelopOraclePyth internal oracle;
    Predicter internal predicter;
    MockERC20 internal mockUsdt;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);
    address public realUsdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address feedRegistry = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf;
    uint256 maxStale = 3600;
    address pyth = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;
    address oraclePyth = 0x10A877328959d5b655Bc0bba03aba2b383114bfa;

    function setUp() public {
        
        mockUsdt = new MockERC20("Mock", "MOCK");  
        oracle = EnvelopOraclePyth(oraclePyth);
        predicter = new Predicter(feeBeneficiary);
    }

    function test_EndtoEnd() public onlyOnFork {
        uint40 exp = uint40(block.timestamp + 100);
        uint96 strikeAmount = 1_000_000;
        uint96 portfolioAmount = 100e6;
        uint96 predictedPrice = 100;
        mockUsdt.mint(userYes, strikeAmount);
        mockUsdt.mint(userNo, strikeAmount);

        Predicter.Prediction memory pred;
    
        CompactAsset[] memory portfolio = new CompactAsset[](4);
        portfolio[0] = CompactAsset({token: 0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898, amount: 366702137679190322});
        portfolio[1] = CompactAsset({token: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, amount: 148283992390774848});
        portfolio[2] = CompactAsset({token: 0x232CE3bd40fCd6f80f3d55A522d03f25Df784Ee2, amount: 375630743327951715});
        portfolio[3] = CompactAsset({token: 0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb, amount: 320748538407361185});

        pred.strike = CompactAsset({token: address(mockUsdt), amount: strikeAmount});
        pred.predictedPrice = OracleData({oracle: address(oracle), amount: predictedPrice});
        pred.expirationTime = exp;
        pred.resolvedPrice = 0;
        pred.portfolio = portfolio;
    

        vm.prank(creator);
        predicter.createPrediction(pred);
        vm.startPrank(userYes);

        mockUsdt.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        vm.stopPrank();

        // usersNo vote 
        vm.startPrank(userNo);
        mockUsdt.approve(address(predicter), strikeAmount);
        predicter.vote(creator, false);
        vm.stopPrank();

        vm.warp(block.timestamp + 200);
        vm.prank(userYes);
        predicter.claim(creator);

        vm.prank(userNo);
        predicter.claim(creator);

        (,,,,,, uint256 currentPrice) = predicter.getUserEstimates(userNo, creator);

        // check balances
        assertGt(currentPrice,0);
        assertEq(mockUsdt.balanceOf(userNo), 0);
        assertEq(mockUsdt.balanceOf(address(predicter)), 0);
        uint256 calculatedCreatorFee = predicter.FEE_CREATOR_PERCENT() * strikeAmount / predicter.PERCENT_DENOMINATOR();
        uint256 calculatedProtocolFee = predicter.FEE_PROTOCOL_PERCENT() * strikeAmount / predicter.PERCENT_DENOMINATOR();
        assertEq(mockUsdt.balanceOf(creator), calculatedCreatorFee);
        assertEq(mockUsdt.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()), calculatedProtocolFee);
        uint256 reward = strikeAmount - calculatedCreatorFee - calculatedProtocolFee;
        assertEq(mockUsdt.balanceOf(userYes), reward + strikeAmount);

        //console2.log(oracle.getTokenDecimals(0xdAC17F958D2ee523a2206206994597C13D831ec7));
    }
}

/* forge test --match-contract PredicterTest_a_fork_1 --rpc-url mainnet -vvvv */