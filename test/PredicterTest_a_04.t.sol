// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/utils/Predicter.sol";
import "../src/mock/MockOracle.sol";
import "../src/mock/MockERC20.sol";
import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import "../src/impl/WNFTV2Index.sol";
import "../src/impl/WNFTV2Envelop721.sol";

contract PredicterTest_a_04 is Test  {
    MockERC20 internal strikeToken;
    MockERC20 internal priceToken;
    MockERC20 internal portfolioToken;
    MockOracle internal oracle;
    Predicter internal predicter;
    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    EnvelopWNFTFactory public factory;
    WNFTV2Index public impl_index;

    address internal creator = address(0xC0FFEE);
    address internal userYes = address(0xBEEF1);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);

    address[] public usersYes;
    address[] public usersNo;

    struct Fees {
        uint256 calculatedCreatorFee;
        uint256 calculatedBeneficiaryFee;
    }

    struct IndexCallParams {
        bytes data;
        address target;
        uint256 value;
    }


    function setUp() public {
        strikeToken = new MockERC20("MockS", "MOCKS");
        portfolioToken = new MockERC20("MockP", "MOCKP");
        priceToken = new MockERC20("MockPr", "MOCKPR");
        oracle = new MockOracle();

        predicter = new Predicter(feeBeneficiary);

        // erc20 = new MockERC20("Mock ERC20", "ERC20");
        factory = new EnvelopWNFTFactory();
        impl_index = new WNFTV2Index(address(factory));
        factory.setWrapperStatus(address(impl_index), true); // set wrapper

        // Give users some tokens and approvals
        strikeToken.mint(userYes, 1_000 ether);
        strikeToken.mint(userNo, 1_000 ether);
    }

    function test_fullEnd2End() public {
        uint256[] memory numberParams = new uint256[](2);

        WNFTV2Envelop721.InitParams memory initData =
            WNFTV2Envelop721.InitParams(address(this), "", "", "", new address[](0), new bytes32[](0), numberParams, "");

        vm.prank(address(this));
        address payable _wnftIndex = payable(impl_index.createWNFTonFactory(initData));
        WNFTV2Index index = WNFTV2Index(_wnftIndex);

        uint96 portfolioAmount = 2e18;

        portfolioToken.transfer(address(index), portfolioAmount);

        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 1_000_000;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred;

        // One-asset portfolio
        CompactAsset[] memory portfolio = new CompactAsset[](1);
        portfolio[0] = CompactAsset({token: address(portfolioToken), amount: portfolioAmount});

        pred.strike = CompactAsset({token: address(strikeToken), amount: strikeAmount});
        pred.predictedPrice = OracleData({oracle: address(oracle), amount: predictedPrice});
        pred.expirationTime = exp;
        pred.resolvedPrice = 0;
        pred.portfolio = portfolio;

        IndexCallParams memory indexData;

        indexData.data = abi.encodeWithSelector(Predicter.createPrediction.selector, pred);
        indexData.target = address(predicter);
        indexData.value = 0;

        index.executeEncodedTx(indexData.target, indexData.value, indexData.data);

        // userYes votes
        strikeToken.mint(userYes, strikeAmount);
        vm.startPrank(userYes);
        strikeToken.approve(address(predicter), strikeAmount);
        predicter.vote(_wnftIndex, true);
        vm.stopPrank();
        
        // userNo votes
        vm.startPrank(userNo);
        strikeToken.mint(userNo, strikeAmount);
        strikeToken.approve(address(predicter), strikeAmount);
        predicter.vote(_wnftIndex, false);
        vm.stopPrank();

        // set oracle price > predictedPrice => predictedTrue = true (yes wins)
        uint256 oraclePrice = 200;
        oracle.setPrice(oraclePrice);

        // jump after expiration
        vm.warp(exp + 1);
        vm.prank(userYes);
        predicter.claim(_wnftIndex);
        // resolvedPrice should be set
        (, , , uint96 resolvedPrice) = predicter.predictions(_wnftIndex);
        assertEq(resolvedPrice, oraclePrice);

        assertEq(strikeToken.balanceOf(address(predicter)), 0);
        Fees memory fees;
        fees.calculatedCreatorFee = ( strikeAmount * predicter.FEE_CREATOR_PERCENT() )/ predicter.PERCENT_DENOMINATOR();
        fees.calculatedBeneficiaryFee = ( strikeAmount * predicter.FEE_PROTOCOL_PERCENT() )/ predicter.PERCENT_DENOMINATOR();

        assertEq(fees.calculatedBeneficiaryFee, strikeToken.balanceOf(predicter.FEE_PROTOCOL_BENEFICIARY()));
        assertEq(fees.calculatedCreatorFee, strikeToken.balanceOf(_wnftIndex));
    }
}