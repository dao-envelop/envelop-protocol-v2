// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../src/utils/Predicter.sol";

contract PredictionBuilder {
    
    function _buildPrediction(address erc20, uint40 expiration, uint96 strikeAmount, uint96 predictedAmount)
        internal
        pure
        returns (Predicter.Prediction memory pred)
    {
        // One-asset portfolio
        CompactAsset[] memory portfolio = new CompactAsset[](1);
        portfolio[0] = CompactAsset({token: erc20, amount: 1 ether});

        pred.strike = CompactAsset({token: erc20, amount: strikeAmount});
        pred.predictedPrice = CompactAsset({token: erc20, amount: predictedAmount});
        pred.expirationTime = expiration;
        pred.resolvedPrice = 0;
        pred.portfolio = portfolio;
    }
}
