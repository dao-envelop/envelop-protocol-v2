// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/utils/Predicter.sol";
import "./helpers/PredictionBuilder.sol";
import "../src/mock/MockOracle.sol";
import "../src/mock/MockERC20.sol";

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

contract PredicterTest_ai is Test, PredictionBuilder {
    MockERC20 internal token;
    MockOracle internal oracle;
    Predicter internal predicter;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);

    MockPermit2 internal mockPermit2;


    function setUp() public {
        token = new MockERC20("Mock", "MOCK");
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
        uint96 strikeAmount = 10e18;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

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

    function test_voteWithPermit2_transfersViaPermit2AndMintsShares() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 10e18;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred = _buildPrediction(address(token), exp, strikeAmount, predictedPrice);

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
