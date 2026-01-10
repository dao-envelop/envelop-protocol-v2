// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/utils/Predicter.sol";
import "./helpers/PredictionBuilder.sol";
import "../src/mock/MockOracle.sol";
import "../src/mock/MockERC20.sol";

contract PredicterTest_a_03 is Test, PredictionBuilder  {
    MockERC20 internal token;
    MockOracle internal oracle;
    Predicter internal predicter;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);

    address[] public usersYes;
    address[] public usersNo;


    function setUp() public {
        token = new MockERC20("Mock", "MOCK");
        oracle = new MockOracle();

        predicter = new Predicter(feeBeneficiary, address(oracle));

        // Give users some tokens and approvals
        token.mint(userYes, 1_000 ether);
        token.mint(userNo, 1_000 ether);
    }

    // ------------------------------------------------------------
    // _resolvePrediction via claim
    // ------------------------------------------------------------

    function test_resolvePrediction_setsResolvedPriceAndClaimPays() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 1_000_000;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        uint256 totalYesAmount;
        uint256 totalNoAmount;
        uint256 yesNum = 4111;
        uint256 noNum = 3;

        // usersYes vote
        for (uint256 i = 0; i < yesNum; i++) {
            address user = address(uint160(i+100));
            token.mint(user, strikeAmount);
            vm.startPrank(user);
            token.approve(address(predicter), strikeAmount);
            predicter.vote(creator, true);
            //console2.log('user = ', user);
            //console2.log('user balance = ', predicter.balanceOf(user, 1002111867590296475548309107748372481));
            vm.stopPrank();
            totalYesAmount+= strikeAmount;
            usersYes.push(user);
        }

        // usersNo vote 
        for (uint256 i = yesNum; i < yesNum + noNum; i++) {
            address user = address(uint160(i));
            vm.startPrank(user);
            token.mint(user, strikeAmount);
            token.approve(address(predicter), strikeAmount);
            predicter.vote(creator, false);
            totalNoAmount+= strikeAmount;
            usersNo.push(user);
            vm.stopPrank();
        }

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        uint256 oraclePrice = 200;
        oracle.setPrice(oraclePrice);

        // jump after expiration
        vm.warp(exp + 1);
    
        uint256 usersYesTotalBalance;
        for (uint256 i = 0; i < usersYes.length; i++) {
            vm.prank(usersYes[i]);
            predicter.claim(creator);
            usersYesTotalBalance += token.balanceOf(usersYes[i]);
        }

        // resolvedPrice should be set
        (, , , uint96 resolvedPrice) = predicter.predictions(creator);
        assertEq(resolvedPrice, oraclePrice);
        uint256 inaccuracyAmount = 4000;
        uint256 predicterBalance = token.balanceOf(address(predicter));
        uint256 creatorBalance = token.balanceOf(address(creator));
        uint256 beneficiaryBalance = token.balanceOf(address(feeBeneficiary));
        assertLt(token.balanceOf(address(predicter)), inaccuracyAmount);
        uint256 allStrikes = totalNoAmount + totalYesAmount;
        uint256 expectedBalances = predicterBalance + creatorBalance + beneficiaryBalance + usersYesTotalBalance;
        assertEq(allStrikes, expectedBalances);
        uint256 calculatedBeneficiaryFee = ( totalNoAmount * predicter.FEE_PROTOCOL_PERCENT() )/ predicter.PERCENT_DENOMINATOR();
        assertApproxEqAbs(calculatedBeneficiaryFee, beneficiaryBalance, 1500);
        uint256 calculatedCreatorFee = ( totalNoAmount * predicter.FEE_CREATOR_PERCENT() )/ predicter.PERCENT_DENOMINATOR();
        assertApproxEqAbs(calculatedCreatorFee, creatorBalance, 2500);
    }

    function test_claim_nonParticipant() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 predictedPrice = 100;
        uint96 strikeAmount = 10 ether;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // yes: userYes (1 vote)
        vm.startPrank(userYes);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        uint256 oraclePrice = 200;
        oracle.setPrice(oraclePrice);
        address nonParticipant = address(1);
        assertEq(token.balanceOf(nonParticipant), 0);  

        // jump after expiration
        vm.warp(exp + 1);
        vm.prank(nonParticipant);
        predicter.claim(creator); 
        assertEq(token.balanceOf(nonParticipant), 0);  
    }

    function test_claim_noWinnerNoRevert() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 predictedPrice = 100;
        uint96 strikeAmount = 10 ether;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // only userNo votes "no"
        vm.startPrank(userNo);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, false);
        vm.stopPrank();

        // set oracle price LOWER than predictedPrice => predictedTrue = false => "no" wins
        uint256 oraclePrice = 50;
        oracle.setPrice(oraclePrice);

        vm.warp(exp + 1);

        // userYes has no winning tokens, should not revert, just no reward
        uint256 before = token.balanceOf(userYes);
        vm.prank(userYes);
        predicter.claim(creator);
        uint256 afterBal = token.balanceOf(userYes);

        assertEq(before, afterBal);
    }

    function test_resolvePrediction_revertOraclePriceTooHigh() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 predictedPrice = 100;
        uint96 strikeAmount = 10 ether;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // userYes votes "yes"
        vm.startPrank(userYes);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        // set oracle price above uint96.max
        uint256 oraclePrice = uint256(type(uint96).max) + 1;
        oracle.setPrice(oraclePrice);

        vm.warp(exp + 1);

        vm.prank(userYes);
        vm.expectRevert(
            abi.encodeWithSelector(Predicter.OraclePriceTooHigh.selector, uint256(type(uint96).max) + 1)
        );
        predicter.claim(creator);
    }

    function test_resolvePrediction_claimInOtherPrediction() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 predictedPrice = 100;
        uint96 strikeAmount = 10 ether;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);
        address creatorForOtherPred = address(100);
        vm.prank(creatorForOtherPred);
        predicter.createPrediction(pred);

        // yes: userYes (1 vote) - first voting
        vm.startPrank(userYes);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        // no: userNo (1 vote)  - first voting
        vm.startPrank(userNo);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, false);
        vm.stopPrank();

        // no: user (1 vote) - second voting
        address voterForSecPred = address(100);
        token.mint(voterForSecPred, 10e18);
        vm.startPrank(voterForSecPred);
        token.approve(address(predicter), 10e18);
        predicter.vote(creatorForOtherPred, false);
        vm.stopPrank();

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        uint256 oraclePrice = 200;
        oracle.setPrice(oraclePrice);

        // jump after expiration
        vm.warp(exp + 100);

        uint256 balanceBefore = token.balanceOf(userYes);
        uint256 balanceBeforePr = token.balanceOf(address(predicter));
        //somebody can resolves
        vm.prank(userYes);
        predicter.claim(creatorForOtherPred);

        // resolvedPrice should be zero
        (, , , uint96 resolvedPrice) = predicter.predictions(creator);
        assertEq(resolvedPrice, 0);
        // resolvedPrice should be set
        (, , , resolvedPrice) = predicter.predictions(creatorForOtherPred);
        assertEq(resolvedPrice, oraclePrice);    
        assertEq(token.balanceOf(userYes), balanceBefore);
        assertEq(token.balanceOf(address(predicter)), balanceBeforePr);
    }

    function test_resolvePrediction_claimSeveralTimes() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 10 ether;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // yes: users vote 
        address yesVoter1 = address(100);
        address yesVoter2 = address(101);

        vm.startPrank(yesVoter1);
        token.mint(yesVoter1, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        vm.stopPrank();

        vm.startPrank(yesVoter2);
        token.mint(yesVoter2, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        vm.stopPrank();

        // no: users vote 
        address noVoter1 = address(102);
        address noVoter2 = address(103);
        vm.startPrank(noVoter1);
        token.mint(noVoter1, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, false);
        vm.stopPrank();

        vm.startPrank(noVoter2);
        token.mint(noVoter2, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, false);
        vm.stopPrank();

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        uint256 oraclePrice = 200;
        oracle.setPrice(oraclePrice);

        // jump after expiration
        vm.warp(exp + 100);

        uint256 balanceBeforeYesVoter1 = token.balanceOf(address(yesVoter1));
        assertEq(token.balanceOf(creator), 0);
        assertEq(token.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()), 0);
        // claim by yesVoter1 - first time
        vm.prank(yesVoter1);
        predicter.claim(creator);
        
        assertGt(token.balanceOf(yesVoter1), balanceBeforeYesVoter1);
        uint256 balanceCreator = token.balanceOf(creator);
        uint256 balanceProtocol = token.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY());
        assertGt(balanceCreator, 0);
        assertGt(balanceProtocol, 0);

        // claim by yesVoter1 - second time
        balanceBeforeYesVoter1 = token.balanceOf(address(yesVoter1));
        vm.prank(yesVoter1);
        predicter.claim(creator);
        assertEq(token.balanceOf(address(yesVoter1)), balanceBeforeYesVoter1);
        assertEq(balanceCreator, token.balanceOf(creator));
        assertEq(balanceProtocol, token.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()));
        uint256 calcWinPrize = balanceProtocol + balanceCreator + balanceBeforeYesVoter1 - strikeAmount;
        assertEq(calcWinPrize, strikeAmount);
        assertGt(balanceBeforeYesVoter1, strikeAmount);
    }

    function test_resolvePrediction_claimSeveralTimes2() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 10 ether;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // yes: users vote 
        address yesVoter1 = address(100);
        address yesVoter2 = address(101);

        vm.startPrank(yesVoter1);
        token.mint(yesVoter1, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        vm.stopPrank();

        vm.startPrank(yesVoter2);
        token.mint(yesVoter2, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        vm.stopPrank();

        // no: users vote 
        address noVoter1 = address(102);
        address noVoter2 = address(103);
        vm.startPrank(noVoter1);
        token.mint(noVoter1, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, false);
        vm.stopPrank();

        vm.startPrank(noVoter2);
        token.mint(noVoter2, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, false);
        vm.stopPrank();

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        uint256 oraclePrice = 200;
        oracle.setPrice(oraclePrice);

        // jump after expiration
        vm.warp(exp + 100);

        assertEq(token.balanceOf(creator), 0);
        assertEq(token.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()), 0);
        // claim by noVoter1 - first time
        vm.prank(noVoter1);
        predicter.claim(creator);
        
        assertEq(token.balanceOf(noVoter1), 0);
        assertEq(token.balanceOf(creator), 0);
        assertEq(token.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()), 0);

        // claim by noVoter1 - second time
        vm.prank(noVoter1);
        predicter.claim(creator);
        assertEq(token.balanceOf(noVoter1), 0);
        assertEq(token.balanceOf(creator), 0);
        assertEq(token.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()), 0);
    }

    function test_resolvePrediction_claimBeforeExpiredDate() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 10 ether;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        address yesVoter1 = address(100);
        address noVoter1 = address(102);

        vm.startPrank(yesVoter1);
        token.mint(yesVoter1, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        vm.stopPrank();

        vm.startPrank(noVoter1);
        token.mint(noVoter1, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, false);
        vm.stopPrank();

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        uint256 oraclePrice = 200;
        oracle.setPrice(oraclePrice);

        // jump before expiration
        vm.warp(exp - 10000);

        assertEq(token.balanceOf(creator), 0);
        assertEq(token.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()), 0);
        // claim by yesVoter1 
        vm.prank(yesVoter1);
        predicter.claim(creator);
        
        assertEq(token.balanceOf(noVoter1), 0);
        assertEq(token.balanceOf(creator), 0);
        assertEq(token.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()), 0);
        // resolvedPrice should be zero
        (, , , uint96 resolvedPrice) = predicter.predictions(creator);
        assertEq(resolvedPrice, 0);
    }

    function test_repeatClaimAfterChangePrice() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 10 ether;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // yes: users vote 
        address yesVoter1 = address(100);
        address yesVoter2 = address(101);
        vm.startPrank(yesVoter1);
        token.mint(yesVoter1, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        vm.stopPrank();

        vm.startPrank(yesVoter2);
        token.mint(yesVoter2, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, true);
        vm.stopPrank();

        // no: users vote 
        address noVoter1 = address(102);
        address noVoter2 = address(103);
        vm.startPrank(noVoter1);
        token.mint(noVoter1, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, false);
        vm.stopPrank();

        vm.startPrank(noVoter2);
        token.mint(noVoter2, strikeAmount);
        token.approve(address(predicter), strikeAmount);
        predicter.vote(creator, false);
        vm.stopPrank();

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        uint256 oraclePrice = 50;
        oracle.setPrice(oraclePrice);

        // jump before expiration
        vm.warp(exp + 100);

        // claim by noVoter1 - first time
        vm.prank(noVoter1);
        predicter.claim(creator);
        
        // resolvedPrice should be zero
        (, , , uint96 resolvedPrice) = predicter.predictions(creator);
        assertEq(resolvedPrice, oraclePrice);


        // claim by noVoter1 - second time
        oraclePrice = 75;
        oracle.setPrice(oraclePrice);
        vm.prank(noVoter2);
        predicter.claim(creator);
        (, , , resolvedPrice) = predicter.predictions(creator);
        assertLt(resolvedPrice, oraclePrice);
    }
}