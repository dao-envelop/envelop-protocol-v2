// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
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

/// @dev Mock oracle returning a configurable price.
contract MockOracle is IEnvelopOracle {
    uint256 public price;

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function getIndexPrice(address) external view override returns (uint256) {
        return 0;
    }

    function getIndexPrice(CompactAsset[] calldata)
        external
        view
        override
        returns (uint256)
    {
        return price;
    }
}

contract PredicterTest_a_03 is Test {
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
        token = new MockERC20();
        oracle = new MockOracle();

        predicter = new Predicter(feeBeneficiary, address(oracle));

        // Give users some tokens and approvals
        token.mint(userYes, 1_000 ether);
        token.mint(userNo, 1_000 ether);
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
    // _resolvePrediction via claim
    // ------------------------------------------------------------

    function test_resolvePrediction_setsResolvedPriceAndClaimPays() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 1000_000;
        Predicter.Prediction memory pred = _buildPrediction(exp, strikeAmount, 100);

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
        oracle.setPrice(200);

        // jump after expiration
        vm.warp(exp + 1);

        for (uint256 i = 0; i < usersYes.length; i++) {
            vm.prank(usersYes[i]);
            predicter.claim(creator);
        }

        // resolvedPrice should be set
        (, , , uint96 resolvedPrice) = predicter.predictions(creator);
        assertEq(resolvedPrice, 200);
        //assertEq(token.balanceOf(address(predicter)), 0);
        console2.log('predicter balance after all claimes = ', token.balanceOf(address(predicter)));
        console2.log('account balance = 1000_000 + reward = ', token.balanceOf(usersYes[0]));

        // resolvedPrice should be set
        /*(, , , uint96 resolvedPrice) = predicter.predictions(creator);
        assertEq(resolvedPrice, 200);

        uint256 balanceAfterUser   = token.balanceOf(userYes);
        uint256 balanceAfterCr     = token.balanceOf(creator);
        uint256 balanceAfterProto  = token.balanceOf(feeBeneficiary);
        uint256 contractBalanceAfter = token.balanceOf(address(predicter));

        // User must have received back stake + net reward > 0
        assertGt(balanceAfterUser, balanceBeforeUser);

        // Creator and protocol both get some fee cut
        assertGt(balanceAfterCr, balanceBeforeCr);
        assertGt(balanceAfterProto, balanceBeforeProto);

        // Контракт уменьшил баланс (выплаты сделаны)
        assertLt(contractBalanceAfter, contractBalanceBefore);*/
    }

    function test_claim_nonParticipant() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // yes: userYes (1 vote)
        vm.startPrank(userYes);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        oracle.setPrice(200);
        address nonParticipant = address(1);
        assertEq(token.balanceOf(nonParticipant), 0);  

        // jump after expiration
        vm.warp(exp + 1);
        vm.prank(nonParticipant);
        predicter.claim(creator); 
        assertEq(token.balanceOf(nonParticipant), 0);  
    }
}