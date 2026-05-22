// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";
import "../src/utils/Predicter.sol";
import "../src/mock/MockOracle.sol";
import "../src/mock/MockERC20.sol";

/// Deploy and init actions
contract InteractScriptPredictor2 is Script {
    using stdJson for string;

    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        
        Predicter predicter = Predicter(0x71B7a17299592e06b80c28C6aB1C1DB5dC67D06D);

        uint256 strikeAmount = 1 ether; 
        address predictionCreator = 0x110FA9c41cb43c08ad98391dFb52a9A0713d9613; 

        Predicter.Prediction memory t = predicter.predictions(predictionCreator);
        
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


         

    }
}

//to run vote with permit2
/*forge script script/InteractScriptPredictor.s.sol:InteractScriptPredictor --rpc-url https://arbitrum-one.public.blastapi.io  --account secret2 --sender 0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E --broadcast -vvvv --via-ir*/
/*forge script script/InteractScriptPredictor.s.sol:InteractScriptPredictor --rpc-url https://arbitrum-one.public.blastapi.io  --account secret1 --sender 0xf315B9006C20913D6D8498BDf657E778d4Ddf2c4 --broadcast -vvvv --via-ir*/




