// SPDX-License-Identifier: MIT
// Envelop V2 — Simple Price Prediction (Voting) Implementation

pragma solidity ^0.8.24;


import {ERC6909TokenSupply} from "@openzeppelin/contracts/token/ERC6909/extensions/ERC6909TokenSupply.sol";
/// forge-lint: disable-next-line(unaliased-plain-import)
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// forge-lint: disable-next-line(unaliased-plain-import)
import "../interfaces/IEnvelopOracle.sol";

/**
 * @title Predicter
 * @notice A decentralized binary prediction market based on ERC-6909 share tokens.
 *         Each prediction is created by an initiator (“creator”) and users may vote
 *         “agree” or “disagree” by staking ERC20 tokens. After expiration, the prediction
 *         resolves via an on-chain oracle, and winners claim rewards proportional to their share.
 *
 * @dev Uses ERC6909 token IDs encoded as:
 *      [20 bytes: creator address][11 bytes: padding][1 byte: vote (1=yes, 0=no)]
 *
 * @custom:security Envelop V2 module
 */
contract Predicter is ERC6909TokenSupply {
    using SafeERC20 for IERC20;    

    /**
     * @dev Single prediction entity created by an address. A creator may have only one active prediction.
     *
     * - strike: token/amount encoded pair representing the stake size for each vote.
     * - predictedPrice: prediction target value (predicted by creator).
     * - expirationTime: timestamp after which new votes stop.
     * - resolvedPrice: oracle result after expiration.
     * - portfolio: array of underlying assets used by the oracle for pricing.
     */
    struct Prediction {
        CompactAsset strike;
        CompactAsset predictedPrice;
        uint40 expirationTime;     
        uint96 resolvedPrice;      
        CompactAsset[] portfolio;  
    }

    // ==================================
    //            CONSTANTS
    // ==================================

    uint40 public constant STOP_BEFORE_EXPIRED  = 0;

    // Fees expressed in denominator units (PERCENT_DENOMINATOR = 10,000)
    // Example: 200,000 / (100 * 10,000) = 20%
    uint96 public constant FEE_CREATOR_PERCENT  = 200000;  
    uint96 public constant FEE_PROTOCOL_PERCENT = 100000;  
    uint96 public constant PERCENT_DENOMINATOR = 10000;

    uint256 public constant MAX_PORTFOLIO_LEN = 100;

    // Uniswap Permit2 constant (not used yet in this version)
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /// Protocol-level fee receiver
    address public immutable FEE_PROTOCOL_BENEFICIARY;

    /// Oracle used for resolving predictions
    address public immutable ORACLE;

    /// Mapping of prediction creator → prediction data
    mapping(address creator => Prediction) public predictions;

    // ==================================
    //            ERRORS
    // ==================================

    /// Thrown when a creator attempts to create a second active prediction
    error ActivePredictionExist(address sender);

    /// Thrown when voting  happens after expiration
    error PredictionExpired(address prediction, uint40 expirationTime);

    /// Thrown if the prediction is referenced but does not exist
    error PredictionNotExist(address prediction);

    error OraclePriceTooHigh(uint256 oraclePrice);

    error TooManyPortfolioItems(uint256 actualLength);


    event PredictionCreated(address indexed creator, uint40 expirationTime);
    event Voted(address indexed voter, address indexed prediction, bool agree);
    event PredictionResolved(address indexed prediction, uint256 resolvedPrice); 
    event Claimed(address indexed user, address indexed prediction, uint256 reward);


    // ==================================
    //           CONSTRUCTOR
    // ==================================

    /**
     * @param _feeBeneficiary Address receiving protocol-level fees.
     * @param _oracle Address of index price oracle.
     */
    constructor(address _feeBeneficiary, address _oracle) {
        FEE_PROTOCOL_BENEFICIARY = _feeBeneficiary;
        ORACLE = _oracle;
    }
    
    // ==================================
    //           USER FUNCTIONS
    // ==================================

    /**
     * @notice Create a new prediction owned by msg.sender.
     *         A creator may only have one active prediction at a time.
     * @param _pred The prediction parameters.
     */
    function createPrediction(Prediction calldata _pred) external {
        if (_pred.portfolio.length > MAX_PORTFOLIO_LEN) {
            revert TooManyPortfolioItems(_pred.portfolio.length);
        }
        _createPrediction(msg.sender, _pred);
        emit PredictionCreated(msg.sender, _pred.expirationTime);
    }

    /**
     * @notice Cast a vote on a prediction by staking tokens.
     * @param _prediction Address of the prediction creator.
     * @param _agree Whether the user votes “yes” (true) or “no” (false).
     */
    function vote(address _prediction, bool _agree) external {
        _vote(msg.sender, _prediction, _agree);
    }
    
    /**
     * @notice Claim rewards based on resolved prediction outcome.
     * @param _prediction Address of prediction creator.
     */
    function claim(address _prediction) external {
        if (_resolvePrediction(_prediction)) {
            _claim(msg.sender, _prediction);
        }
    }

    
    function getUserEstimates(address _user, address _prediction) external view 
    returns(
        uint256 yesBalance, 
        uint256 noBalance, 
        uint256 yesTotal, 
        uint256 noTotal, 
        uint256 yesReward, 
        uint256 noReward
    )
    {
        (uint256 yesToken, uint256 noToken) = hlpGet6909Ids(_prediction);
        yesBalance = balanceOf(_user, yesToken);
        noBalance = balanceOf(_user, noToken);
        yesTotal = totalSupply(yesToken);
        noTotal = totalSupply(noToken);

        if (yesTotal > 0) {
            yesReward = noTotal * (yesBalance * PERCENT_DENOMINATOR / yesTotal) / PERCENT_DENOMINATOR;
        }

        if (noTotal > 0){
           noReward = yesTotal * (noBalance * PERCENT_DENOMINATOR / noTotal) / PERCENT_DENOMINATOR;     
        }
        
    }

    function hlpGet6909Ids(address _prediction) public pure returns(uint256 yesId, uint256 noId){
        yesId = (uint256(uint160(_prediction)) << 96) | 1;
        noId  = (uint256(uint160(_prediction)) << 96);
    }

    // ==================================
    //           INTERNAL LOGIC
    // ==================================

    /**
     * @dev Internal implementation of prediction creation.
     *      Reverts if creator already has an active prediction.
     */
    function _createPrediction(address _creator, Prediction calldata _pred) internal virtual {
        Prediction storage p = predictions[_creator];
        if (p.expirationTime != 0) {
            revert ActivePredictionExist(_creator);
        }
        predictions[_creator] = _pred;
    }

    /**
     * @dev Internal voting logic.
     *      Mints ERC6909 vote-shares and pulls the user's ERC20 stake.
     * @param _user Voting user.
     * @param _prediction Prediction creator address.
     * @param _agree Vote type (true=yes, false=no).
     */
    function _vote(address _user, address _prediction, bool _agree) internal {
        Prediction storage p = predictions[_prediction];
        if (p.expirationTime == 0) revert PredictionNotExist(_prediction);

        // if not expired yet
        if (p.expirationTime > block.timestamp) {
            CompactAsset storage s = p.strike;

            // Construct 6909 tokenId
            uint256 tokenId =
                (uint256(uint160(_prediction)) << 96) | (_agree ? 1 : 0);

            // Mint share tokens equal to strike amount
            _mint(_user, tokenId, s.amount);

            // Pull user’s ERC20 stake
            IERC20(s.token).safeTransferFrom(_user, address(this), s.amount);
        } else {
            revert PredictionExpired(_prediction, p.expirationTime);
        }
        emit Voted(_user, _prediction, _agree);
    }

    /**
     * @dev Resolve a prediction by fetching its actual price from oracle.
     *      Only executes once per prediction.
     */
    function _resolvePrediction(address _prediction) internal returns(bool isResolved){
        Prediction storage p = predictions[_prediction];
        if (
                p.expirationTime <= block.timestamp  // time to resolve came 
                && p.resolvedPrice == 0              // implicit Resolved Flag
            ) 
            {
            
                // Oracle returns the final price for the selected asset composition
                uint256 oracle_price = IEnvelopOracle(ORACLE).getIndexPrice(p.portfolio);
                if (oracle_price > type(uint96).max) {
                    revert OraclePriceTooHigh(oracle_price);
                }
                p.resolvedPrice = uint96(oracle_price);
                emit PredictionResolved(_prediction, oracle_price);
            }
        isResolved = p.resolvedPrice > 0;
    }

    /**
     * @dev Claim the reward for a winning voter.
     *      Handles:
     *        - returning the original stake
     *        - pulling back 6909 share tokens
     *        - distributing fee to creator + protocol
     *        - paying remaining reward to user
     */
    function _claim(address _user, address _prediction) internal {
        (
            uint256 winTokenId,
            uint256 winTokenBalance,
            ,
            uint256 winnerPrize
        ) = _getWinnerShareAndAmount(_user, _prediction);

        uint256 paid;
        uint256 fee;

        if (winnerPrize > 0) {
            CompactAsset storage s = predictions[_prediction].strike;

            // 1. Return original stake
            IERC20(s.token).safeTransfer(_user, winTokenBalance);
            
            // 2. Pull back ERC6909 share tokens
            _transfer(_user, address(this), winTokenId, winTokenBalance);

            // 3. Creator fee
            fee = winnerPrize * FEE_CREATOR_PERCENT / (100 * PERCENT_DENOMINATOR);
            paid += fee;
            IERC20(s.token).safeTransfer(_prediction, fee);
            
            // 4. Protocol fee
            fee = winnerPrize * FEE_PROTOCOL_PERCENT / (100 * PERCENT_DENOMINATOR);
            paid += fee;
            IERC20(s.token).safeTransfer(FEE_PROTOCOL_BENEFICIARY, fee);
            
            // 5. User reward
            IERC20(s.token).safeTransfer(_user, winnerPrize - paid);

            emit Claimed(_user, _prediction, winnerPrize - paid);
        }
    }

    /**
     * @dev Calculates:
     *        - tokenId of winning vote
     *        - user balance of winning tokens
     *        - user's share percentage (non-denominated)
     *        - total reward owed, proportional to losing pool
     */
    function _getWinnerShareAndAmount(
        address _user,
        address _prediction
    )
        internal 
        view 
        returns(
            uint256 winTokenId,
            uint256 winTokenBalance,
            uint256 sharesNonDenominated,
            uint256 prizeAmount
        )
    {
        Prediction storage p = predictions[_prediction];

        // True if predictedPrice <= actual oracle result
        bool predictedTrue = p.predictedPrice.amount <= p.resolvedPrice;

        // Determine winning and losing token IDs
        winTokenId =
            (uint256(uint160(_prediction)) << 96) | (predictedTrue ? 1 : 0);
        uint256 loserTokenId =
            (uint256(uint160(_prediction)) << 96) | (!predictedTrue ? 1 : 0);

        winTokenBalance = balanceOf(_user, winTokenId);

        // User share = userVotes / totalVotes
        sharesNonDenominated =
            winTokenBalance * PERCENT_DENOMINATOR / totalSupply(winTokenId);

        // Prize = share * totalLosingPool
        prizeAmount =
            totalSupply(loserTokenId) * sharesNonDenominated / PERCENT_DENOMINATOR;
    }
}
