// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/utils/Predicter.sol";
import "../src/utils/PredictionBuilder.sol";
import "../src/mock/MockOracle.sol";
import "../src/mock/MockERC20.sol";

contract PredicterTest_a_02 is Test, PredictionBuilder {
    MockERC20 internal token;
    MockOracle internal oracle;
    Predicter internal predicter;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);


    function setUp() public {
        token = new MockERC20("Mock", "MOCK");
        oracle = new MockOracle();

        predicter = new Predicter(feeBeneficiary, address(oracle));

        // Give users some tokens and approvals
        token.mint(userYes, 1_000 ether);
        token.mint(userNo, 1_000 ether);
    }

    // ------------------------------------------------------------
    // vote
    // ------------------------------------------------------------

    function test_vote_mintsSharesAndTransfersStake() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 10e18;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // userYes votes "yes"
        (uint256 yesId, ) = predicter.hlpGet6909Ids(creator);

        vm.startPrank(userYes);
        token.approve(address(predicter), strikeAmount);
        vm.expectEmit();
        emit Predicter.Voted(userYes, creator, true);
        predicter.vote(creator, true);
        vm.stopPrank();

        assertEq(predicter.balanceOf(userYes, yesId), strikeAmount);
        assertEq(token.balanceOf(address(predicter)), strikeAmount);
    }

    function test_vote_revertPredictionNotExist() public {
        vm.prank(userYes);
        vm.expectRevert(
            abi.encodeWithSelector(Predicter.PredictionNotExist.selector, address(0xDEAD))
        );
        predicter.vote(address(0xDEAD), true);
    }

    function test_vote_revertPredictionExpired() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 10e18;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        vm.warp(exp + 10);
        vm.startPrank(userYes);
        vm.expectRevert(
            abi.encodeWithSelector(Predicter.PredictionExpired.selector, creator, exp)
        );
        predicter.vote(creator, true);
        vm.stopPrank();
    }

    function test_vote_secondTimeTrue() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 10e18;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // userYes votes "yes"
        (uint256 yesId, ) = predicter.hlpGet6909Ids(creator);

        vm.startPrank(userYes);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        vm.stopPrank();

        assertEq(predicter.balanceOf(userYes, yesId), 2 * strikeAmount);
        assertEq(token.balanceOf(address(predicter)), 2 * strikeAmount);
    }

    function test_vote_secondTime_firstTrue_secondFalse() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 10e18;
        uint96 predictedPrice = 100;
        address voter = address(1);
        token.mint(voter, 1_000 ether);
        
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // userYes votes "yes"
        (uint256 yesId, ) = predicter.hlpGet6909Ids(creator);
        // userYes votes "yes"
        (, uint256 noId) = predicter.hlpGet6909Ids(creator);


        vm.startPrank(voter);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, false);
        vm.stopPrank();

        assertEq(predicter.balanceOf(voter, yesId), strikeAmount);
        assertEq(token.balanceOf(address(predicter)), 2 * strikeAmount);
        assertEq(predicter.balanceOf(voter, noId), strikeAmount);
    }
}