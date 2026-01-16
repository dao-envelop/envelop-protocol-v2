// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/utils/Predicter.sol";
import "../../src/utils/EnvelopOracle.sol";
import "../../src/mock/MockERC20.sol";
import "./BaseForkTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PredicterTest_a_fork_1 is BaseForkTest  {
    MockERC20 internal mock;
    EnvelopOracle internal oracle;
    Predicter internal predicter;
    MockERC20 internal usdtContract;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);
    address public usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address feedRegistry = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf;
    uint256 maxStale = 36000000000;

    function setUp() public {
        
        mock = new MockERC20("Mock", "MOCK");  
        oracle = new EnvelopOracle(feedRegistry, maxStale);

        predicter = new Predicter(feeBeneficiary, address(oracle));

        bytes memory mockCode = address(mock).code;
        vm.etch(usdt, mockCode);
        usdtContract = MockERC20(usdt);
    }

    function test_EndtoEnd() public onlyOnFork {
        uint40 exp = uint40(block.timestamp + 100);
        uint96 strikeAmount = 1_000_000;
        uint96 portfolioAmount = 1e8;
        uint96 predictedPrice = 100;
        usdtContract.mint(userYes, strikeAmount);
        usdtContract.mint(userNo, strikeAmount);

        Predicter.Prediction memory pred;
    
        CompactAsset[] memory portfolio = new CompactAsset[](1);
        portfolio[0] = CompactAsset({token: usdt, amount: portfolioAmount});

        pred.strike = CompactAsset({token: usdt, amount: strikeAmount});
        pred.predictedPrice = CompactAsset({token: usdt, amount: predictedPrice});
        pred.expirationTime = exp;
        pred.resolvedPrice = 0;
        pred.portfolio = portfolio;
    

        vm.prank(creator);
        predicter.createPrediction(pred);
        vm.startPrank(userYes);
        usdtContract.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        vm.stopPrank();

        // usersNo vote 
        vm.startPrank(userNo);
        usdtContract.approve(address(predicter), strikeAmount);
        predicter.vote(creator, false);
        vm.stopPrank();

        vm.warp(block.timestamp + 200);
        vm.prank(userYes);
        predicter.claim(creator);

        vm.prank(userNo);
        predicter.claim(creator);

        // check balances
        assertEq(usdtContract.balanceOf(userNo), 0);
        assertEq(usdtContract.balanceOf(address(predicter)), 0);
        uint256 calculatedCreatorFee = predicter.FEE_CREATOR_PERCENT() * strikeAmount / predicter.PERCENT_DENOMINATOR();
        uint256 calculatedProtocolFee = predicter.FEE_PROTOCOL_PERCENT() * strikeAmount / predicter.PERCENT_DENOMINATOR();
        assertEq(usdtContract.balanceOf(creator), calculatedCreatorFee);
        assertEq(usdtContract.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()), calculatedProtocolFee);
        uint256 reward = strikeAmount - calculatedCreatorFee - calculatedProtocolFee;
        assertEq(usdtContract.balanceOf(userYes), reward + strikeAmount);
    }
}

/* forge test --match-contract PredicterTest_a_fork_1 --rpc-url mainnet -vvvv */