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

contract MockPermit2 is IPermit2 {
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata /*signature*/
    ) external override {
        // Просто делаем transferFrom токена от owner к transferDetails.to
        IERC20(permit.permitted.token).transferFrom(
            owner,
            transferDetails.to,
            transferDetails.requestedAmount
        );
    }
}


contract PredicterTest is Test {
    MockERC20 internal token;
    MockOracle internal oracle;
    Predicter internal predicter;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);

    MockPermit2 internal mockPermit2;


    function setUp() public {
        token = new MockERC20();
        oracle = new MockOracle();

        predicter = new Predicter(feeBeneficiary, address(oracle));

        // deploy mock Permit2 and replace PERMIT2
        mockPermit2 = new MockPermit2();
        // replace code at address  Predicter.PERMIT2()
        vm.etch(predicter.PERMIT2(), address(mockPermit2).code);

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

    // ------------------------------------------------------------
    // vote
    // ------------------------------------------------------------

    function test_vote_mintsSharesAndTransfersStake() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // userYes votes "yes"
        (uint256 yesId, ) = predicter.hlpGet6909Ids(creator);

        vm.startPrank(userYes);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        assertEq(predicter.balanceOf(userYes, yesId), 10 ether);
        assertEq(token.balanceOf(address(predicter)), 10 ether);
    }

    function test_vote_revertPredictionNotExist() public {
        vm.prank(userYes);
        vm.expectRevert(
            abi.encodeWithSelector(Predicter.PredictionNotExist.selector, address(0xDEAD))
        );
        predicter.vote(address(0xDEAD), true);
    }

    function test_vote_revertPredictionExpired() public {
        uint40 exp = uint40(block.timestamp); // already expired
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        vm.startPrank(userYes);
        token.approve(address(predicter), 10 ether);
        vm.expectRevert(
            abi.encodeWithSelector(Predicter.PredictionExpired.selector, creator, exp)
        );
        predicter.vote(creator, true);
        vm.stopPrank();
    }

    // ------------------------------------------------------------
    // hlpGet6909Ids
    // ------------------------------------------------------------

    function test_hlpGet6909Ids_encoding() public view {
        (uint256 yesId, uint256 noId) = predicter.hlpGet6909Ids(creator);

        assertEq(yesId, (uint256(uint160(creator)) << 96) | 1);
        assertEq(noId, (uint256(uint160(creator)) << 96));
    }

    // ------------------------------------------------------------
    // getUserEstimates
    // ------------------------------------------------------------

    function test_getUserEstimates_basic() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // userYes votes 1x yes
        vm.startPrank(userYes);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        // userNo votes 2x no
        vm.startPrank(userNo);
        token.approve(address(predicter), 20 ether);
        predicter.vote(creator, false);
        predicter.vote(creator, false);
        vm.stopPrank();

        (
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

        // userYes owns 1/1 of yes pool, loser pool size = 20 ether
        assertEq(yesReward, 20 ether);
        // userYes has 0 noTokens, so noReward = 0
        assertEq(noReward, 0);
    }

    // ------------------------------------------------------------
    // _resolvePrediction via claim
    // ------------------------------------------------------------

    function test_resolvePrediction_setsResolvedPriceAndClaimPays() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // yes: userYes (1 vote)
        vm.startPrank(userYes);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        // no: userNo (1 vote)
        vm.startPrank(userNo);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, false);
        vm.stopPrank();

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        oracle.setPrice(200);

        // jump after expiration
        vm.warp(exp + 1);

        uint256 balanceBeforeUser   = token.balanceOf(userYes);
        uint256 balanceBeforeCr     = token.balanceOf(creator);
        uint256 balanceBeforeProto  = token.balanceOf(feeBeneficiary);
        uint256 contractBalanceBefore = token.balanceOf(address(predicter));

        vm.prank(userYes);
        predicter.claim(creator);

        // resolvedPrice should be set
        (, , , uint96 resolvedPrice) = predicter.predictions(creator);
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
        assertLt(contractBalanceAfter, contractBalanceBefore);
    }

    function test_resolvePrediction_revertOraclePriceTooHigh() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // userYes votes "yes"
        vm.startPrank(userYes);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, true);
        vm.stopPrank();

        // set oracle price above uint96.max
        oracle.setPrice(uint256(type(uint96).max) + 1);

        vm.warp(exp + 1);

        vm.prank(userYes);
        vm.expectRevert(
            abi.encodeWithSelector(Predicter.OraclePriceTooHigh.selector, uint256(type(uint96).max) + 1)
        );
        predicter.claim(creator);
    }

    function test_claim_noWinnerNoRevert() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        // only userNo votes "no"
        vm.startPrank(userNo);
        token.approve(address(predicter), 10 ether);
        predicter.vote(creator, false);
        vm.stopPrank();

        // set oracle price LOWER than predictedPrice => predictedTrue = false => "no" wins
        oracle.setPrice(50);

        vm.warp(exp + 1);

        // userYes has no winning tokens, should not revert, just no reward
        uint256 before = token.balanceOf(userYes);
        vm.prank(userYes);
        predicter.claim(creator);
        uint256 afterBal = token.balanceOf(userYes);

        assertEq(before, afterBal);
    }

        function test_voteWithPermit2_transfersViaPermit2AndMintsShares() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        Predicter.Prediction memory pred = _buildPrediction(exp, 10 ether, 100);

        vm.prank(creator);
        predicter.createPrediction(pred);

        (uint256 yesId, ) = predicter.hlpGet6909Ids(creator);

        // userYes give approve to Permit2 contract
        vm.startPrank(userYes);
        token.approve(predicter.PERMIT2(), 10 ether);

        // Prepare Permit2-structs (this mock not check it)
        IPermit2.PermitTransferFrom memory permit;
        permit.permitted = IPermit2.TokenPermissions({
            token: address(token),
            amount: 10 ether
        });
        permit.nonce = 0;
        permit.deadline = block.timestamp + 1 days;

        IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
            to: address(predicter),
            requestedAmount: 10 ether
        });

        bytes memory signature = hex""; // no actual signs check

        
        predicter.voteWithPermit2(
            creator,
            true,
            permit,
            transferDetails,
            signature
        );
        vm.stopPrank();

        assertEq(token.balanceOf(address(predicter)), 10 ether);
        assertEq(predicter.balanceOf(userYes, yesId), 10 ether);
    }

}
