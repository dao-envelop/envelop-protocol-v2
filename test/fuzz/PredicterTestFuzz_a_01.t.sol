// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import "../../src/utils/Predicter.sol";
import "../helpers/PredictionBuilder.sol";
import "../../src/mock/MockERC20.sol";

contract PredicterTestFuzz_a_01 is Test, PredictionBuilder {
    MockERC20 internal token;
    address oracle = address(100);
    Predicter internal predicter;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);
    address[] public usersYes;
    address[] public usersNo;


    function setUp() public {
        token = new MockERC20("Mock", "MOCK");
        predicter = new Predicter(feeBeneficiary, oracle);

    }

    // ------------------------------------------------------------
    // getUserEstimates
    // ------------------------------------------------------------

    function testFuzz_getUserEstimates(uint8 num) public {
        console2.log('num = ', num);
        uint256 totalYesAmount;
        uint256 totalNoAmount;
        //vm.assume(num > 10);
        num = uint8(bound(num, 10, 95));
        
        uint8 yesNum = num;
        uint8 noNum = 255 - num;
        //uint8 yesNum = 3;
        //uint8 noNum = 7;

        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 1_000_000;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);


        vm.prank(creator);
        predicter.createPrediction(pred);

        // userYes votes

        for (uint8 i = 0; i < yesNum; i++) {
            address user = address(uint160(i+100));
            vm.startPrank(user);
            token.mint(user, 1_000 ether);
            token.approve(address(predicter), 1 ether);
            predicter.vote(creator, true);
            totalYesAmount+= 1 ether;
            usersYes.push(user);
            vm.stopPrank();
        }
        
        // userNo votes no
        //for (uint8 i = noNum; i < 255; i++) {
        for (uint8 i = yesNum; i < yesNum + noNum; i++) {
            address user = address(uint160(i));
            vm.startPrank(user);
            token.mint(user, 1_000 ether);
            token.approve(address(predicter), 1 ether);
            predicter.vote(creator, false);
            totalNoAmount+= 1 ether;
            usersNo.push(user);
            vm.stopPrank();

        }

        uint256 calculatedNoTotal;
        uint256 expectedYesTotal;
        uint256 expectedNoTotal;
        for (uint8 i = 0; i < usersYes.length; i++) {
            //console2.log('usersYes[i] = ', usersYes[i]);
            (
            uint256 yesBalance,
            uint256 noBalance,
            uint256 yesTotal,
            uint256 noTotal,
            uint256 yesReward,
            uint256 noReward
            ) = predicter.getUserEstimates(usersYes[i], creator);
            calculatedNoTotal += yesReward;
            expectedYesTotal = yesTotal;
            expectedNoTotal = noTotal;
        }

        uint256 calculatedYesTotal;
        for (uint8 i = 0; i < usersNo.length; i++) {
            //console2.log('usersNo[i] = ', usersNo[i]);
            (
            uint256 yesBalance,
            uint256 noBalance,
            uint256 yesTotal,
            uint256 noTotal,
            uint256 yesReward,
            uint256 noReward
            ) = predicter.getUserEstimates(usersNo[i], creator);
            calculatedYesTotal += noReward;
        }
        assertApproxEqAbs(expectedYesTotal, calculatedYesTotal, 12000);
        assertApproxEqAbs(expectedNoTotal, calculatedNoTotal, 12000);
    }
}