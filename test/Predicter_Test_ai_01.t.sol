// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/utils/Predicter.sol"; // поправь путь под свой проект
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// Простой ERC20 для тестов
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1e27);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// Мок оракла, который просто возвращает заранее установленную цену
contract MockOracle {
    uint256 public price;

    function setPrice(uint256 _price) external {
        price = _price;
    }

    // Важно: сигнатура должна совпасть с той, которую вызывает Predicter
    function getIndexPrice(CompactAsset[] calldata)
        external
        view
        returns (uint256)
    {
        return price;
    }
}

/// Хелпер-контракт, чтобы вытащить internal-функции наружу
contract PredicterHarness is Predicter {
    constructor(address feeBeneficiary, address oracle)
        Predicter(feeBeneficiary, oracle)
    {}

    function exposedChargeFee(address _prediction, uint256 _prizeAmount)
        external
        returns (uint256)
    {
        return _chargeFee(_prediction, _prizeAmount);
    }

    function exposedGetWinnerShareAndAmount(address _user, address _prediction)
        external
        view
        returns (
            uint256 winTokenId,
            uint256 winTokenBalance,
            uint256 sharesNonDenominated,
            uint256 prizeAmount
        )
    {
        return _getWinnerShareAndAmount(_user, _prediction);
    }
}

contract PredicterTest is Test {
    MockERC20 internal token;
    MockOracle internal oracle;
    PredicterHarness internal predicter;

    address internal creator = address(0xC0FFEE);
    address internal userWin = address(0xBEEF1);
    address internal userLose = address(0xBEEF2);

    function setUp() public {
        token = new MockERC20();
        oracle = new MockOracle();

        predicter = new PredicterHarness(
            address(0xFEE_FEE_FEE_FEE),
            address(oracle)
        );

        // немного токенов пользователям
        token.mint(userWin, 1_000 ether);
        token.mint(userLose, 1_000 ether);
    }

    /// Вспомогалка: собрать Prediction
    function _buildPrediction(uint40 expiration, uint96 strikeAmount, uint96 predictedPriceAmount)
        internal
        view
        returns (Predicter.Prediction memory pred)
    {
        // портфель из одного актива (для оракула)
        CompactAsset[] memory portfolio = new CompactAsset[](1);
        portfolio[0] = CompactAsset({
            token: address(token),
            amount: 1 ether
        });

        pred.strike = CompactAsset({
            token: address(token),
            amount: strikeAmount
        });
        pred.predictedPrice = CompactAsset({
            token: address(token),
            amount: predictedPriceAmount
        });
        pred.expirationTime = expiration;
        pred.resolvedPrice = 0;
        pred.portfolio = portfolio;
    }

    // ------------------------------------------------------------
    // createPrediction
    // ------------------------------------------------------------

    function test_createPrediction_storesData_andRevertsOnSecond() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 100 ether, 150);

        // первый вызов от creator
        vm.prank(creator);
        predicter.createPrediction(pred);

        (
            CompactAsset memory strike,
            CompactAsset memory predictedPrice,
            uint40 expirationTime,
            uint96 resolvedPrice
        ) = predicter.predictions(creator);

        assertEq(strike.token, address(token));
        assertEq(strike.amount, 100 ether);
        assertEq(predictedPrice.amount, 150);
        assertEq(expirationTime, exp);
        assertEq(resolvedPrice, 0);

        // второй вызов должен ревертиться ActivePredictionExist
        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(
                Predicter.ActivePredictionExist.selector,
                creator
            )
        );
        predicter.createPrediction(pred);
    }

    // ------------------------------------------------------------
    // vote
    // ------------------------------------------------------------

    function test_vote_mints6909_andTransfersStake() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 150);

        // предикция от creator
        vm.prank(creator);
        predicter.createPrediction(pred);

        // userWin голосует "за"
        vm.startPrank(userWin);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        // ожидаемый tokenId: (creator << 96) | 1
        uint256 yesId =
            (uint256(uint160(creator)) << 96) | uint256(1);

        assertEq(predicter.balanceOf(userWin, yesId), 10 ether);
        assertEq(token.balanceOf(address(predicter)), 10 ether);

        // userLose голосует "против"
        vm.startPrank(userLose);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, false);
        vm.stopPrank();

        uint256 noId =
            (uint256(uint160(creator)) << 96) | uint256(0);

        assertEq(predicter.balanceOf(userLose, noId), 10 ether);
        assertEq(token.balanceOf(address(predicter)), 20 ether);
    }

    // ------------------------------------------------------------
    // _resolvePrediction (через claim)
    // ------------------------------------------------------------

    function test_resolvePrediction_setsResolvedPrice_afterExpiry() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // userWin голосует
        vm.startPrank(userWin);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        // устанавливаем цену из оракула
        oracle.setPrice(200); // > predictedPrice.amount → должен быть "true"

        // отматываем время за expiration
        vm.warp(exp + 1);

        // claim: внутри вызовется _resolvePrediction
        vm.prank(userWin);
        // ВНИМАНИЕ: сейчас этот вызов РЕВЕРТИТСЯ из-за бага в _claim (см. ниже),
        // поэтому сначала проверяем resolvedPrice через try/catch-паттерн у vm.expectRevert
        vm.expectRevert(); // из-за неверного safeTransferFrom в _claim
        predicter.claim(creator);

        // но _resolvePrediction вызывается ДО _claim и успевает записать resolvedPrice,
        // поэтому мы можем проверить его
        (
            ,
            ,
            ,
            uint96 resolvedPrice
        ) = predicter.predictions(creator);

        assertEq(resolvedPrice, 200, "resolvedPrice must be set from oracle");
    }

    // ------------------------------------------------------------
    // _getWinnerShareAndAmount (через harness)
    // ------------------------------------------------------------

    function test_getWinnerShareAndAmount_singleWinnerVsSingleLoser() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        // predictedPrice.amount = 100
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // userWin голосует "за"
        vm.startPrank(userWin);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        // userLose голосует "против"
        vm.startPrank(userLose);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, false);
        vm.stopPrank();

        // выставляем цену > predictedPrice => predictedTrue = true
        oracle.setPrice(200);
        vm.warp(exp + 1);

        // сначала резолвим (чтобы записать resolvedPrice)
        // используем прямой вызов claim, но ожидаем revert на фазе _claim
        vm.prank(userWin);
        vm.expectRevert();
        predicter.claim(creator);

        // теперь считаем долю победителя через harness
        (
            uint256 winTokenId,
            uint256 winBal,
            uint256 shareNonDenom,
            uint256 prize
        ) = predicter.exposedGetWinnerShareAndAmount(userWin, creator);

        // winner = userWin с yesTokenId
        uint256 yesId =
            (uint256(uint160(creator)) << 96) | uint256(1);

        assertEq(winTokenId, yesId);
        assertEq(winBal, 10 ether);

        // totalSupply(winId) = 10 ether → shareNonDenom = 10000 (100%)
        assertEq(shareNonDenom, predicter.PERCENT_DENOMINATOR());

        // totalSupply(loserId) = 10 ether → приз = 10 ether
        assertEq(prize, 10 ether);
    }

    // ------------------------------------------------------------
    // _chargeFee (явно покажет баг с transferFrom)
    // ------------------------------------------------------------

    function test_chargeFee_revertsDueToTransferFromBug() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // зальём контракт токенами, чтобы у него был баланс
        token.mint(address(predicter), 100 ether);

        // попытаемся списать fee: внутри _chargeFee используется
        // IERC20(s.token).safeTransferFrom(address(this), _prediction, charged)
        // что для стандартного ERC20 ревернётся из-за отсутствия allowance
        vm.expectRevert();
        predicter.exposedChargeFee(creator, 10 ether);
    }
}
