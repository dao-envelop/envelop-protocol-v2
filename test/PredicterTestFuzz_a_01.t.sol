// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import "../src/utils/Predicter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Simple ERC20 mock for staking in tests.
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1e27);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredicterTestFuzz_a_01 is Test {
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
        token = new MockERC20();

        predicter = new Predicter(feeBeneficiary, oracle);

    }

    // ------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------

    function _buildPrediction(uint40 expiration, uint96 strikeAmount, uint96 predictedAmount)
        internal
        view
        returns (Predicter.Prediction memory pred)
    {
        // One-asset portfolio
        CompactAsset[] memory portfolio = new CompactAsset[](1);
        uint96 portfolioAmount = 1e18;
        portfolio[0] = CompactAsset({token: address(token), amount: portfolioAmount});

        pred.strike = CompactAsset({token: address(token), amount: strikeAmount});
        pred.predictedPrice = CompactAsset({token: address(token), amount: predictedAmount});
        pred.expirationTime = expiration;
        pred.resolvedPrice = 0;
        pred.portfolio = portfolio;
    }

    // ------------------------------------------------------------
    // getUserEstimates
    // ------------------------------------------------------------

    function testFuzz_getUserEstimates(uint8 num) public {
    //function testFuzz_getUserEstimates() public {
        uint256 totalYesAmount;
        uint256 totalNoAmount;
        //vm.assume(num > 10);
        num = uint8(bound(num, 10, 95));
        console2.log('num = ', num);
        uint8 yesNum = num;
        uint8 noNum = 255 - num;
        //uint8 yesNum = 3;
        //uint8 noNum = 7;

        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 1 ether, 100);

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
        
        

        // userNo votes 2x no
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
        //console2.log('totalYesAmount = ', totalYesAmount);
        //console2.log('totalNoAmount = ', totalNoAmount);

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
            /*console2.log('yes yesBalance = ', yesBalance);
            console2.log('yes noBalance = ', noBalance);
            console2.log('yes yesTotal = ', yesTotal);
            console2.log('yes noTotal = ', noTotal);
            console2.log('yes yesReward = ', yesReward);
            console2.log('yes noReward = ', noReward);
            console2.log('**********************************************');*/

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
            /*console2.log('no yesBalance = ', yesBalance);
            console2.log('no noBalance = ', noBalance);
            console2.log('no yesTotal = ', yesTotal);
            console2.log('no noTotal = ', noTotal);
            console2.log('no yesReward = ', yesReward);
            console2.log('no noReward = ', noReward);
            console2.log('**********************************************');*/

        }

        console2.log('expectedYesTotal = ', expectedYesTotal);
        console2.log('expectedNoTotal = ', expectedNoTotal);
        console2.log('calculatedYesTotal = ', calculatedYesTotal);
        console2.log('calculatedNoTotal = ', calculatedNoTotal);
        assertEq(expectedYesTotal, calculatedYesTotal);
        assertEq(expectedNoTotal, calculatedNoTotal);


        /*(
            uint256 yesBalance,
            uint256 noBalance,
            uint256 yesTotal,
            uint256 noTotal,
            uint256 yesReward,
            uint256 noReward
        ) = predicter.getUserEstimates(userYes, creator);

        (uint256 yesId, uint256 noId) = predicter.hlpGet6909Ids(creator);

        assertEq(yesBalance, predicter.balanceOf(userYes, yesId));
        assertEq(noBalance, predicter.balanceOf(userYes, noId));
        assertEq(yesTotal, predicter.totalSupply(yesId));
        assertEq(noTotal, predicter.totalSupply(noId));

        assertEq(yesReward+)*/
    }
}