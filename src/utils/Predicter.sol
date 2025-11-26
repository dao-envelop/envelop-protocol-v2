// SPDX-License-Identifier: MIT
// Envelop V2, Simple Predictor implementation


pragma solidity ^0.8.24;

import {ERC6909TokenSupply} from  "@openzeppelin/contracts/token/ERC6909/extensions/ERC6909TokenSupply.sol";

/// forge-lint: disable-next-line(unaliased-plain-import)
import  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
/// forge-lint: disable-next-line(unaliased-plain-import)
import "../interfaces/IEnvelopOracle.sol";
/**
 * @dev Simple Predictor implementation for Envelop V2 
 */
contract Predicter is ERC6909TokenSupply {
    using SafeERC20 for IERC20;    
    // struct CompactAsset {
    //     address token; // 20 byte
    //     uint96 amount; // 12 byte
    // }

    struct Prediction {
        CompactAsset strike;          // 1slot (32b)
        CompactAsset predictedPrice;  // 1slot (32b)
        uint40 expirationTime;        //  5 byte
        uint96 resolvedPrice;         // 12 byte  
        CompactAsset[] portfolio;     //  1slot x array length
    }

    uint40 public constant STOP_BEFORE_EXPIRED  = 0;
    uint96 public constant FEE_CREATOR_PERCENT  = 200000;  // 10% - 100_000
    uint96 public constant FEE_PROTOCOL_PERCENT = 100000;  // 10% - 100_000
    uint96 public constant PERCENT_DENOMINATOR = 10000;
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public immutable FEE_PROTOCOL_BENEFICIARY;
    address public immutable ORACLE;

    mapping(address creator => Prediction) public predictions;

    error ActivePredictionExist(address sender);
    error PredictionExpired(address prediction, uint40 expirationTime);
    error PredictionNotExist(address prediction);

    constructor (address _feeBeneficiary, address _oracle) {
        FEE_PROTOCOL_BENEFICIARY = _feeBeneficiary;
        ORACLE = _oracle;
    }
    
    function createPrediction(Prediction calldata _pred) 
        external 
    {
        // Base case for this contract when v2 index create prediction from itself 
        _createPrediction(msg.sender, _pred);
    }

    function vote(address _prediction, bool _agree) external {
        _vote(msg.sender, _prediction, _agree);
    }
    
    function claim(address _prediction) external {
        _resolvePrediction(_prediction);
        _claim(msg.sender, _prediction);
    }
    ///////////////////////////////////////////////////////////////////////////
    ///                    Internals                                        ///
    ///////////////////////////////////////////////////////////////////////////
    function _createPrediction(address _creator, Prediction calldata _pred) internal {
        Prediction storage p = predictions[_creator];
        if (p.expirationTime != 0) {
            revert ActivePredictionExist(_creator);
        }
        predictions[_creator] = _pred;
    }

    function _vote(address _user, address _prediction, bool _agree) internal {
        Prediction storage p = predictions[_creator];
        if (p.expirationTime == 0) {
            revert PredictionNotExist(_prediction);
        }

        if (p.expirationTime > block.timestamp ) {
            CompactAsset storage s = p.strike;
            _mint(_user, (uint256(uint160(_prediction)) << 96) | (_agree ? 1 : 0), s.amount);
            IERC20(s.token).safeTransferFrom(_user, address(this), s.amount);
        } else {
            revert PredictionExpired(_prediction, p.expirationTime);
        }
    }

    function _resolvePrediction(address _prediction) internal {
        Prediction storage p = predictions[_prediction];
        if (p.expirationTime <= block.timestamp && p.resolvedPrice == 0) {
           // TODO check max
           p.resolvedPrice = uint96(IEnvelopOracle(ORACLE).getIndexPrice(p.portfolio)); 
        }
    }

    function _claim(address _user, address _prediction) internal {
        (uint256 winTokenId, uint256 winTokenBalance, , uint256 winnerPrize) 
            = _getWinnerShareAndAmount(_user, _prediction);
        // TODO think about remove this check due gas save
        if (winnerPrize > 0){
            _burn(_user, winTokenId, winTokenBalance);
            CompactAsset storage s = predictions[_prediction].strike;
            // TODO add fee spliting
            IERC20(s.token).safeTransfer( _user, winnerPrize);
        }
    }

    function _chargeFee(address _prediction, uint256 _prizeAmount) 
        internal 
        returns(uint256 charged)
    {
        CompactAsset storage s = predictions[_prediction].strike;
        charged = _prizeAmount * FEE_CREATOR_PERCENT / (100 * PERCENT_DENOMINATOR);
        IERC20(s.token).safeTransfer( _prediction, charged);
        uint256 protocolFee = _prizeAmount * FEE_PROTOCOL_PERCENT / (100 * PERCENT_DENOMINATOR); 
        charged += protocolFee;
    } 

    function _getWinnerShareAndAmount(address _user, address _prediction) 
        internal 
        view 
        returns(uint256 winTokenId, uint256 winTokenBalance, uint256 sharesNonDenominated, uint256 prizeAmount)
    {
        Prediction storage p = predictions[_prediction];
        bool predictedTrue = p.predictedPrice.amount <= p.resolvedPrice;
        winTokenId   = (uint256(uint160(_prediction)) << 96) | ( predictedTrue ? 1 : 0);
        uint256 loserTokenId = (uint256(uint160(_prediction)) << 96) | (!predictedTrue ? 1 : 0);
        winTokenBalance = balanceOf(_user, winTokenId);
        sharesNonDenominated = winTokenBalance * PERCENT_DENOMINATOR / totalSupply(winTokenId);
        prizeAmount = totalSupply(loserTokenId) * sharesNonDenominated / PERCENT_DENOMINATOR;
    }
}
