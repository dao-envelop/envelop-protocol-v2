// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/utils/Predicter.sol";
import "./helpers/PredictionBuilder.sol";
import "../src/mock/MockOracle.sol";
import "../src/mock/MockERC20.sol";

contract PredicterTest_m_01 is Test, PredictionBuilder {
    MockERC20 internal token;
    MockOracle internal oracle;
    Predicter internal predicter;
    struct LogFields{
        uint256 oneYesReward;
        uint256 estTotalFeeBenef;
        uint256 estTotalFeeCreator;
    }

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);

    address[] public usersYes;
    address[] public usersNo;

    LogFields l;

    function setUp() public {
        token = new MockERC20("Mock", "MOCK");
        oracle = new MockOracle();

        predicter = new Predicter(feeBeneficiary, address(oracle));

        // Give users some tokens and approvals
        token.mint(userYes, 1_000 ether);
        token.mint(userNo, 1_000 ether);
    }

    function test_resolvePrediction_onlyWinnersBets() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 1_000_000;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        uint256 totalYesAmount;
        uint256 totalNoAmount;
        uint256 yesNum = 411;
        //uint256 noNum = 0;
        
        address user;
        // usersYes vote
        for (uint256 i = 0; i < yesNum; i++) {
            user = address(uint160(i+100));
            token.mint(user, strikeAmount);
            vm.startPrank(user);
            token.approve(address(predicter), strikeAmount);
            predicter.vote(creator, true);
            vm.stopPrank();
            totalYesAmount += strikeAmount;
            usersYes.push(user);
        }

        l.estTotalFeeBenef = totalNoAmount * predicter.FEE_PROTOCOL_PERCENT() * predicter.SCALE()
          /predicter.PERCENT_DENOMINATOR()/ predicter.SCALE();
        console2.log('Estimate Beneficiary Fee Amount: %s', l.estTotalFeeBenef);    

        l.estTotalFeeCreator = totalNoAmount * predicter.FEE_CREATOR_PERCENT() * predicter.SCALE()
          /predicter.PERCENT_DENOMINATOR() / predicter.SCALE();
        console2.log('Estimate Creator     Fee Amount: %s', l.estTotalFeeCreator);


        l.oneYesReward = (totalNoAmount / yesNum - l.estTotalFeeBenef / yesNum- l.estTotalFeeCreator/ yesNum) ;
        console2.log('Estimate Reward Amount: %s', l.oneYesReward);  
        
        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        uint256 oraclePrice = 200;
        oracle.setPrice(oraclePrice);

        // jump after expiration
        vm.warp(exp + 1);
        console2.log('predicter balance before all claimes: %s', token.balanceOf(address(predicter)));  
        assertEq(token.balanceOf(address(predicter)), totalNoAmount + totalYesAmount);   
        (uint256 yesToken, uint256 noToken) = predicter.hlpGet6909Ids(address(creator));
        bool isValidGame = (predicter.totalSupply(yesToken) > 0 && predicter.totalSupply(noToken) > 0);
        console2.log('yesTokenSuplpy: %s, noTokenSupply: %s, game is valid: %s',
            predicter.totalSupply(yesToken), predicter.totalSupply(noToken), isValidGame
        );  
        assertEq(
            token.balanceOf(address(predicter)), 
            predicter.totalSupply(yesToken) + predicter.totalSupply(noToken)
        );


        // claims
        for (uint256 i = 0; i < usersYes.length; i++) {
            vm.prank(usersYes[i]);
            predicter.claim(creator);
            assertEq(token.balanceOf(address(usersYes[i])), strikeAmount); 
        }

        // resolvedPrice should be set
        (, , , uint96 resolvedPrice) = predicter.predictions(creator);
        assertEq(resolvedPrice, oraclePrice);
        //assertEq(token.balanceOf(address(predicter)), 0);
        console2.log('predicter balance after all claimes:  %s', token.balanceOf(address(predicter)));
        console2.log('creater   balance after all claimes:  %s', token.balanceOf(address(creator)));
        console2.log('beneficia balance after all claimes:  %s', token.balanceOf(address(feeBeneficiary)));
        console2.log('One Yes voter balance after claimes:  %s', token.balanceOf(usersYes[0]));
        assertEq(token.balanceOf(address(predicter)), 0);   

    }

    function test_resolvePrediction_onlyNoBets() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 1_000_000;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

        vm.prank(creator);
        predicter.createPrediction(pred);

        uint256 totalYesAmount;
        uint256 totalNoAmount;
        uint256 yesNum = 0;
        uint256 noNum = 23;
        
        address user;

        // usersNo vote 
        for (uint256 i = yesNum; i < yesNum + noNum; i++) {
            user = address(uint160(i + 100));
            vm.startPrank(user);
            token.mint(user, strikeAmount);
            token.approve(address(predicter), strikeAmount);
            predicter.vote(creator, false);
            totalNoAmount += strikeAmount;
            usersNo.push(user);
            vm.stopPrank();
        }

        l.estTotalFeeBenef = totalNoAmount * predicter.FEE_PROTOCOL_PERCENT() * predicter.SCALE()
          /predicter.PERCENT_DENOMINATOR()/ predicter.SCALE();
        console2.log('Estimate Beneficiary Fee Amount: %s', l.estTotalFeeBenef);    

        l.estTotalFeeCreator = totalNoAmount * predicter.FEE_CREATOR_PERCENT() * predicter.SCALE()
          /predicter.PERCENT_DENOMINATOR() / predicter.SCALE();
        console2.log('Estimate Creator     Fee Amount: %s', l.estTotalFeeCreator);

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        uint256 oraclePrice = 200;
        oracle.setPrice(oraclePrice);

        // jump after expiration
        vm.warp(exp + 1);
        console2.log('predicter balance before all claimes: %s', token.balanceOf(address(predicter)));  
        assertEq(token.balanceOf(address(predicter)), totalNoAmount + totalYesAmount);   

        // claims
        console2.log('Claiming %s users........', usersNo.length);  
        for (uint256 i = 0; i < usersNo.length; i++) {
            vm.prank(usersNo[i]);
            predicter.claim(creator);
            assertEq(token.balanceOf(address(usersNo[i])), strikeAmount); 
        }

        // resolvedPrice should be set
        (, , , uint96 resolvedPrice) = predicter.predictions(creator);
        assertEq(resolvedPrice, oraclePrice);
        //assertEq(token.balanceOf(address(predicter)), 0);
        console2.log('predicter balance after all claimes:  %s', token.balanceOf(address(predicter)));
        console2.log('creater   balance after all claimes:  %s', token.balanceOf(address(creator)));
        console2.log('beneficia balance after all claimes:  %s', token.balanceOf(address(feeBeneficiary)));
        console2.log('One Yes voter balance after claimes:  %s', token.balanceOf(usersNo[0]));
        assertEq(token.balanceOf(address(predicter)), 0); 
        assertEq(token.balanceOf(creator), 0); 
        assertEq(token.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()), 0); 
    }   
}