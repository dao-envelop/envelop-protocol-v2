// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/utils/Predicter.sol";
import "../../src/interfaces/IPermit2Minimal.sol";
import "../../src/utils/EnvelopOracle.sol";
import "../../src/mock/MockERC20.sol";
import "./BaseForkTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PredicterTest_a_fork_2 is BaseForkTest  {
    MockERC20 internal usdt;
    EnvelopOracle internal oracle;
    Predicter internal predicter;

    address internal creator = address(0xC0FFEE);
    address public constant userYes = 0x4b664eD07D19d0b192A037Cfb331644cA536029d;
    uint256 public constant userYesPRIVKEY = 0x3480b19b170c5e63c0bdb18d08c4a99628194c7dceaf79e0e17431f4a5c7b1f2;
    address internal feeBeneficiary = address(0xFEEBEEF);
    address feedRegistry = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf;
    uint256 maxStale = 36000000000;

    function setUp() public {
        
        usdt = new MockERC20("Mock", "MOCK");  
        oracle = new EnvelopOracle(feedRegistry, maxStale);
        predicter = new Predicter(feeBeneficiary, address(oracle));
    }

    function test_voteWithPermit() public onlyOnFork {
        
        uint40 exp = uint40(block.timestamp + 100);
        uint96 strikeAmount = 1_000_000;
        uint96 portfolioAmount = 1e8;
        uint96 predictedPrice = 100;
        usdt.mint(userYes, strikeAmount);

        Predicter.Prediction memory pred;
    
        CompactAsset[] memory portfolio = new CompactAsset[](1);
        portfolio[0] = CompactAsset({token: address(usdt), amount: portfolioAmount});

        pred.strike = CompactAsset({token: address(usdt), amount: strikeAmount});
        pred.predictedPrice = CompactAsset({token: address(usdt), amount: predictedPrice});
        pred.expirationTime = exp;
        pred.resolvedPrice = 0;
        pred.portfolio = portfolio;
    

        vm.prank(creator);
        predicter.createPrediction(pred);

        vm.startPrank(userYes);
        usdt.approve(predicter.PERMIT2(), type(uint256).max);
        
        uint256 deadline = block.timestamp + 1 days;
        (IPermit2Minimal.PermitTransferFrom memory permit, bytes32 digest) = predicter.hlpGetPermitAndDigest(creator, deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userYesPRIVKEY, digest);
        bytes memory signature =  bytes.concat(r, s, bytes1(v));

        predicter.voteWithPermit2(
            creator,
            true,
            permit,
            //transferDetails,
            signature
        );

        vm.stopPrank();
    }
}

/* forge test --match-contract PredicterTest_a_fork_2 --rpc-url mainnet -vvvv */