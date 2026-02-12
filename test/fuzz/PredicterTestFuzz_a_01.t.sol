// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import "../../src/utils/Predicter.sol";
import "../helpers/PredictionBuilder.sol";
import "../../src/mock/MockERC20.sol";
import "../../src/mock/MockOracle.sol";

contract PredicterTestFuzz_a_01 is Test, PredictionBuilder {
    MockERC20 internal token;
    MockOracle internal oracle;
    Predicter internal predicter;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);
    address[] public usersYes;
    address[] public usersNo;

    struct Fees {
        uint256 feeYesBeneficiary;
        uint256 feeNoBeneficiary;
        uint256 feeYesProtocol;
        uint256 feeNoProtocol;
    }


    function setUp() public {
        token = new MockERC20("Mock", "MOCK");
        oracle = new MockOracle();
        predicter = new Predicter(feeBeneficiary);

    }

    // ------------------------------------------------------------
    // getUserEstimates
    // ------------------------------------------------------------

    function testFuzz_getUserEstimates(uint8 num) public {
        //console2.log('num = ', num);

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
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice, address(oracle));


        vm.prank(creator);
        predicter.createPrediction(pred);

        // userYes votes

        for (uint8 i = 0; i < yesNum; i++) {
            address user = address(uint160(i+100));
            vm.startPrank(user);
            token.mint(user, 1_000 ether);
            token.approve(address(predicter), 1 ether);
            predicter.vote(creator, true);
            totalYesAmount+= strikeAmount;
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
            totalNoAmount+= strikeAmount;
            usersNo.push(user);
            vm.stopPrank();

        }

        vm.warp(exp + 1);
        oracle.setPrice(predictedPrice + 1);
        vm.prank(usersNo[0]);
        predicter.claim(creator);

        uint256 calculatedNoTotal;
        uint256 expectedYesTotal;
        uint256 expectedNoTotal;

        for (uint8 i = 0; i < usersYes.length; i++) {
            //console2.log('usersYes[i] = ', usersYes[i]);
            (
            ,
            ,
            uint256 yesTotal,
            uint256 noTotal,
            uint256 yesReward,
            ,
            ) = predicter.getUserEstimates(usersYes[i], creator);
            calculatedNoTotal += yesReward;

            expectedYesTotal = yesTotal;
            expectedNoTotal = noTotal;
        }

        uint256 calculatedYesTotal;
        for (uint8 i = 0; i < usersNo.length; i++) {
            //console2.log('usersNo[i] = ', usersNo[i]);
            (
            ,
            ,
            ,
            ,
            ,
            uint256 noReward,
            ) = predicter.getUserEstimates(usersNo[i], creator);
            calculatedYesTotal += noReward;
        }
            
        Fees memory fees;

        fees.feeYesBeneficiary = totalYesAmount * predicter.FEE_CREATOR_PERCENT() / predicter.PERCENT_DENOMINATOR();
        fees.feeNoBeneficiary = totalNoAmount * predicter.FEE_CREATOR_PERCENT() / predicter.PERCENT_DENOMINATOR();
        fees.feeYesProtocol = totalYesAmount * predicter.FEE_PROTOCOL_PERCENT() / predicter.PERCENT_DENOMINATOR();
        fees.feeNoProtocol = totalNoAmount * predicter.FEE_PROTOCOL_PERCENT() / predicter.PERCENT_DENOMINATOR();
        assertApproxEqAbs(expectedYesTotal, calculatedYesTotal + fees.feeYesBeneficiary + fees.feeYesProtocol, 12000);
        assertApproxEqAbs(expectedNoTotal, calculatedNoTotal + fees.feeNoBeneficiary + fees.feeNoProtocol, 12000);
    }
}