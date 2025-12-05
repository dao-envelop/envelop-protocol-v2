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



contract PredicterTest_a_01 is Test {
    MockERC20 internal token;
    MockOracle internal oracle;
    Predicter internal predicter;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);

    function setUp() public {
        oracle = new MockOracle();

        predicter = new Predicter(feeBeneficiary, address(oracle));
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
        portfolio[0] = CompactAsset({token: address(token), amount: 1 ether});

        pred.strike = CompactAsset({token: address(token), amount: strikeAmount});
        pred.predictedPrice = CompactAsset({token: address(token), amount: predictedAmount});
        pred.expirationTime = expiration;
        pred.resolvedPrice = 0;
        pred.portfolio = portfolio;
    }

    // ------------------------------------------------------------
    // createPrediction
    // ------------------------------------------------------------

    function test_createPrediction_success() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        vm.expectEmit();
        emit Predicter.PredictionCreated(
            creator,
            exp
        );
        predicter.createPrediction(pred);

        (CompactAsset memory strike,
         CompactAsset memory predictedPrice,
         uint40 expirationTime,
         uint96 resolvedPrice) = predicter.predictions(creator);

        assertEq(strike.token, address(token));
        assertEq(strike.amount, 10 ether);
        assertEq(predictedPrice.amount, 100);
        assertEq(expirationTime, exp);
        assertEq(resolvedPrice, 0);
    }

    function test_createPrediction_revertTooManyPortfolioItems() public {
        // new instance with big portfolio
        CompactAsset[] memory portfolio = new CompactAsset[](predicter.MAX_PORTFOLIO_LEN() + 1);
        for (uint256 i = 0; i < portfolio.length; i++) {
            portfolio[i] = CompactAsset({token: address(token), amount: 1});
        }

        Predicter.Prediction memory pred;
        pred.strike = CompactAsset({token: address(token), amount: 1 ether});
        pred.predictedPrice = CompactAsset({token: address(token), amount: 100});
        pred.expirationTime = uint40(block.timestamp + 1 days);
        pred.portfolio = portfolio;

        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(Predicter.TooManyPortfolioItems.selector, predicter.MAX_PORTFOLIO_LEN() + 1)
        );
        predicter.createPrediction(pred);
    }

    function test_createPrediction_revertActivePredictionExist() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.startPrank(creator);
        predicter.createPrediction(pred);

        // second creation should revert
        //vm.expectPartialRevert(Predicter.ActivePredictionExist.selector);
        vm.expectRevert(
            abi.encodeWithSelector(Predicter.ActivePredictionExist.selector, creator)
        );
        predicter.createPrediction(pred);
        vm.stopPrank();
    }

    function test_createPrediction_revertTooLongPrediction() public {
        uint40 period = predicter.MAX_PREDICTION_PERIOD() + 10;
        uint40 exp = uint40(block.timestamp + period);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.startPrank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(Predicter.TooLongPrediction.selector, exp)
        );
        predicter.createPrediction(pred);
        vm.stopPrank();
    }
}
