// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";
import "../src/utils/Predicter.sol";
import "../src/mock/MockOracle.sol";
import "../src/mock/MockERC20.sol";

/// Deploy and init actions
contract InteractScriptPredictor is Script {
    using stdJson for string;

    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        
        MockERC20 token = MockERC20(0xa9b1a94d8ddBa49193e50174D4f87ee108F5e4cD);
        MockOracle oracle = MockOracle(0x60c0A71A991aAe273c4ACD017Bb03d4FfdFb4996);
        Predicter predicter = Predicter(0x2f1487ffB78FcB29e4bA4811750A1709BE76DBa9);

        uint256 strikeAmount = 1 ether; 
        address predictionCreator = 0xf315B9006C20913D6D8498BDf657E778d4Ddf2c4; 
        uint256  fromPrivateKey = vm.envUint("DEV_PRIVATE_KEY");
        bool agreeVote = true;
        uint256 permitNonce = 12; //change nonce
        uint256 expiration = uint256(block.timestamp + 365 days);

        
        // create prediction
        /*vm.startBroadcast();
        uint96 strikeAmount96 = 1 ether; 
        uint96 predictedAmount96 = 100;
        uint96 portfolioAmount96 = 1 ether;
        CompactAsset[] memory portfolio = new CompactAsset[](1);
        portfolio[0] = CompactAsset({token: address(token), amount: portfolioAmount96});
        Predicter.Prediction memory newPrediction = Predicter.Prediction(
            CompactAsset(address(token), strikeAmount96), 
            OracleData(address(oracle), predictedAmount96), 
            uint40(block.timestamp + 36000000), 
            0, 
            portfolio
        );
        predicter.createPrediction(newPrediction);
        vm.stopBroadcast();*/


        vm.startBroadcast();
        // don't forget make alloawance for permit2
        //token.approve(predicter.PERMIT2(), type(uint256).max);

        uint256 deadline = block.timestamp + 1 days;
        (IPermit2Minimal.PermitTransferFrom memory permit, ,  bytes32 hashedDigest) = predicter.hlpGetPermitAndDigest(predictionCreator, deadline);

        console2.logBytes32(hashedDigest);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromPrivateKey, hashedDigest);
        bytes memory signature =  bytes.concat(r, s, bytes1(v));
        console2.logBytes(signature);

        predicter.voteWithPermit2(
            predictionCreator,
            true,
            permit,
            //transferDetails,
            signature
        );
        vm.stopBroadcast();   

    }
}

//to run vote with permit2
/*forge script script/InteractScriptPredictor.s.sol:InteractScriptPredictor --rpc-url https://arbitrum-one.public.blastapi.io  --account secret2 --sender 0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E --broadcast -vvvv --via-ir*/
/*forge script script/InteractScriptPredictor.s.sol:InteractScriptPredictor --rpc-url https://arbitrum-one.public.blastapi.io  --account secret1 --sender 0xf315B9006C20913D6D8498BDf657E778d4Ddf2c4 --broadcast -vvvv --via-ir*/




