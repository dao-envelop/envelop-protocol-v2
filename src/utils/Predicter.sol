// SPDX-License-Identifier: MIT
// Envelop V2 — Simple Price Prediction (Voting) Implementation

pragma solidity ^0.8.24;


import {ERC6909TokenSupply} from "@openzeppelin/contracts/token/ERC6909/extensions/ERC6909TokenSupply.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// forge-lint: disable-next-line(unaliased-plain-import)
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// forge-lint: disable-next-line(unaliased-plain-import)
import "../interfaces/IEnvelopOracle.sol";

/// forge-lint: disable-next-line(unaliased-plain-import)
//import "../interfaces/IPermit2Minimal.sol";

import "../interfaces/IPermit2Minimal.sol";



/**
 * @title Predicter
 * @notice A decentralized binary prediction market based on ERC-6909 share tokens.
 *         Each prediction is created by an initiator (“creator”) and users may vote
 *         “agree” or “disagree” by staking ERC20 tokens. After expiration, the prediction
 *         resolves via an on-chain oracle, and winners claim rewards proportional to their share.
 *
 * @dev Uses ERC6909 token IDs encoded as:
 *      [20 bytes: creator address][11 bytes: padding][1 byte: vote flag (1 = yes, 0 = no)]
 *
 * @custom:security-contact Envelop V2
 */
contract Predicter is ERC6909TokenSupply, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @dev Single prediction entity created by an address.
     * A creator may have only one active prediction at a time.
     *
     * - strike: token/amount encoded pair representing the stake size for each vote.
     * - predictedPrice: prediction target value (amount field) with token as “unit” asset.
     * - expirationTime: UNIX timestamp after which new votes are not accepted.
     * - resolvedPrice: oracle result after expiration, stored once and used for outcome.
     * - portfolio: array of underlying assets used by the oracle for pricing.
     */
     

    struct Prediction {
        CompactAsset strike;
        /// @dev predictedPrice.amount is a threshold value.
        ///      Outcome is YES if predictedPrice.amount <= resolvedPrice, otherwise NO.
        ///      resolvedPrice must be in the same units/decimals as predictedPrice.amount.
        CompactAsset predictedPrice;
        uint40 expirationTime;
        uint96 resolvedPrice;
        CompactAsset[] portfolio;
    }

    // ==================================
    //            CONSTANTS
    // ==================================

    /// @dev Reserved constant for potential “stop voting before expiration” logic.
    uint40 public constant STOP_BEFORE_EXPIRED = 0;

    /// @dev Creator fee in bps. 200 = 2%
    uint96 public constant FEE_CREATOR_PERCENT = 200;

    /// @dev Protocol fee  in bps. 100 = 1%.
    uint96 public constant FEE_PROTOCOL_PERCENT = 100;

    /// @dev Percentage denominator (basis points = 10_000).
    uint96 public constant PERCENT_DENOMINATOR = 10_000;

    /// @dev Fixed-point scale used to reduce rounding loss in share calculations.
    ///      Shares are computed as: userShares = (userBalance * SCALE) / totalWin.
    uint96 public constant SCALE = 1e18;

    /// @dev Hard cap for number of portfolio items, to avoid gas blow-ups.
    uint256 public constant MAX_PORTFOLIO_LEN = 100;

    /// @dev Hard cap for number of portfolio items, to avoid gas blow-ups.
    uint40 public constant MAX_PREDICTION_PERIOD =  uint40(1000 days);

    /// @dev Uniswap Permit2 constant (reserved for future integrations, currently unused).
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /// @notice Protocol-level fee receiver.
    address public immutable FEE_PROTOCOL_BENEFICIARY;

    /// @notice Oracle used for resolving predictions.
    address public immutable ORACLE;

    /// @notice Mapping of prediction creator → prediction data.
    mapping(address creator => Prediction) public predictions;

    // ==================================
    //            ERRORS
    // ==================================

    /// @dev Thrown when a creator attempts to create a second active prediction.
    error ActivePredictionExist(address sender);

    /// @dev Thrown when voting happens after expiration.
    error PredictionExpired(address prediction, uint40 expirationTime);

    /// @dev Thrown if the prediction is referenced but does not exist.
    error PredictionNotExist(address prediction);

    /// @dev Thrown if oracle price does not fit into uint96.
    error OraclePriceTooHigh(uint256 oraclePrice);

    /// @dev Thrown if portfolio length exceeds MAX_PORTFOLIO_LEN.
    error TooManyPortfolioItems(uint256 actualLength);

    /// @dev Thrown if prediction too long
    error TooLongPrediction(uint256 actualTimestamp);


    // ==================================
    //            EVENTS
    // ==================================

    /// @notice Emitted when a new prediction is created.
    event PredictionCreated(address indexed creator, uint40 expirationTime);

    /// @notice Emitted on each user vote.
    event Voted(address indexed voter, address indexed prediction, bool agree);

    /// @notice Emitted once prediction is resolved with oracle price.
    event PredictionResolved(address indexed prediction, uint256 resolvedPrice);

    /// @notice Emitted when a user successfully claims their reward.
    event Claimed(address indexed user, address indexed prediction, uint256 reward);

    // ==================================
    //           CONSTRUCTOR
    // ==================================

    /**
     * @param _feeBeneficiary Address receiving protocol-level fees.
     * @param _oracle Address of the index price oracle.
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
     *
     * Requirements:
     * - `_pred.portfolio.length` MUST be ≤ MAX_PORTFOLIO_LEN.
     * - Creator MUST NOT have an existing prediction (`expirationTime == 0`).
     */
    function createPrediction(Prediction calldata _pred) external {
        if (_pred.portfolio.length > MAX_PORTFOLIO_LEN) {
            revert TooManyPortfolioItems(_pred.portfolio.length);
        }

        if (_pred.expirationTime > MAX_PREDICTION_PERIOD + uint40(block.timestamp)) {
            revert TooLongPrediction(_pred.expirationTime);
        }
        _checkPrediction(msg.sender, _pred);
        _createPrediction(msg.sender, _pred);
        emit PredictionCreated(msg.sender, _pred.expirationTime);
    }

    /**
     * @notice Cast a vote on a prediction by staking tokens.
     * @param _prediction Address of the prediction creator.
     * @param _agree Whether the user votes “yes” (true) or “no” (false).
     *
     * Emits:
     * - {Voted}
     *
     * Requirements:
     * - Prediction MUST exist.
     * - Current time MUST be strictly less than `expirationTime`.
     * - Caller MUST have approved enough ERC20 to `this` for the strike amount.
     */
    function vote(address _prediction, bool _agree) external nonReentrant() {
        _vote(msg.sender, _prediction, _agree);
    }

        /**
     * @notice Cast a vote using Uniswap Permit2 signature-based transfer.
     * @dev Flow:
     *  1) User gives standard ERC20 approval to Permit2 once (off-chain setup).
     *  2) Для конкретного dApp вызова подписывает EIP-712 под Permit2.
     *  3) В этом методе мы вызываем Permit2.permitTransferFrom, который
     *     переводит stake с пользователя на контракт, и затем минтим 6909-шары.
     *
     * @param _prediction Address of the prediction creator.
     * @param _agree      Whether the user votes “yes” (true) or “no” (false).
     * @param permit      Permit2 permit struct (token, max amount, nonce, deadline).
     * @param transfer    Permit2 transfer details (recipient, requestedAmount).
     * @param signature   User EIP-712 signature for Permit2.
     *
     * Requirements:
     * - Prediction MUST exist.
     * - Now MUST be < expirationTime.
     * - permit.permitted.token MUST match prediction strike token.
     * - transfer.to MUST be this contract.
     * - transfer.requestedAmount MUST be >= strike amount.
     * - owner (msg.sender) MUST have given ERC20 approve to Permit2 beforehand.
     */
    function voteWithPermit2(
        address _prediction,
        bool _agree,
        IPermit2.PermitTransferFrom calldata permit,
        IPermit2.SignatureTransferDetails calldata transfer,
        bytes calldata signature
    ) external nonReentrant() {
        Prediction storage p = predictions[_prediction];
        if (p.expirationTime == 0) revert PredictionNotExist(_prediction);
        if (p.expirationTime <= block.timestamp) {
            revert PredictionExpired(_prediction, p.expirationTime);
        }

        CompactAsset storage s = p.strike;

        // Basic sanity checks to bind Permit2 params to this prediction
        if (permit.permitted.token != s.token) {
            revert("Permit2: wrong token");
        }
        if (transfer.to != address(this)) {
            revert("Permit2: wrong recipient");
        }
        if (transfer.requestedAmount != s.amount) {
            revert("Permit2: insufficient amount");
        }

        // 1) Move tokens from user to this contract via Permit2
        IPermit2(PERMIT2).permitTransferFrom(
            permit,
            transfer,
            msg.sender,
            signature
        );

        // 2) Mint ERC6909 shares to user
        uint256 tokenId =
            (uint256(uint160(_prediction)) << 96) | (_agree ? 1 : 0);
        _mint(msg.sender, tokenId, s.amount);

        emit Voted(msg.sender, _prediction, _agree);
    }


    /**
     * @dev If only one side has any votes (no-contest), voters can refund their stake instead of rewards.
     * @notice Claim rewards based on resolved prediction outcome.
     * @param _prediction Address of prediction creator.
     *
     * Emits:
     * - {PredictionResolved} (if first-time resolve)
     * - {Claimed} (if caller has a positive winner’s prize)
     *
     * Requirements:
     * - Prediction MUST exist and be resolvable (expired).
     * - Caller MUST hold a positive amount of winning share tokens (ERC6909),
     *   otherwise the call is a no-op.
     */
    function claim(address _prediction) external nonReentrant(){
        if (_resolvePrediction(_prediction)) {

            if (_checkIsGameValidAndReturnStakesIfNot(msg.sender, _prediction)){
                _claim(msg.sender, _prediction);    
            }
            
        }
    }

    /**
     * @notice Helper to estimate user positions and raw rewards without executing a claim.
     * @param _user Address of the user.
     * @param _prediction Address of the prediction creator.
     *
     * @return yesBalance User balance of “yes” 6909 tokens.
     * @return noBalance  User balance of “no” 6909 tokens.
     * @return yesTotal   Total supply of “yes” tokens.
     * @return noTotal    Total supply of “no” tokens.
     * @return yesReward  Raw share of loser pool if “yes” wins (before fees).
     * @return noReward   Raw share of loser pool if “no” wins (before fees).
     */
    function getUserEstimates(address _user, address _prediction)
        external
        view
        returns (
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
            yesReward =
                noTotal *
                (yesBalance * SCALE / yesTotal) / SCALE;
        }

        if (noTotal > 0) {
            noReward =
                yesTotal *
                (noBalance * SCALE / noTotal) / SCALE;
        }
    }

    /**
     * @notice Helper to compute ERC6909 token IDs for given prediction.
     * @param _prediction Address of prediction creator.
     * @return yesId Token ID for “yes” shares.
     * @return noId  Token ID for “no” shares.
     *
     * @dev Encoding:
     *      yesId = (uint160(creator) << 96) | 1
     *      noId  = (uint160(creator) << 96)
     */
    function hlpGet6909Ids(address _prediction)
        public
        pure
        returns (uint256 yesId, uint256 noId)
    {
        yesId = (uint256(uint160(_prediction)) << 96) | 1;
        noId = (uint256(uint160(_prediction)) << 96);
    }

    // ==================================
    //           INTERNAL LOGIC
    // ==================================
    function _checkPrediction(address _creator, Prediction calldata _pred)
        internal
        virtual
    {
        
    }

    /**
     * @dev Internal implementation of prediction creation.
     *      Reverts if creator already has an active prediction.
     */
    function _createPrediction(address _creator, Prediction calldata _pred)
        internal
        virtual
    {
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
     * @param _agree Vote type (true = yes, false = no).
     */
    function _vote(address _user, address _prediction, bool _agree) internal {
        Prediction storage p = predictions[_prediction];
        if (p.expirationTime == 0) revert PredictionNotExist(_prediction);

        // Only allow voting before expiration
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
     *      Only executes once per prediction (idempotent).
     *
     * @return isResolved True if prediction has a non-zero resolvedPrice after the call.
     *
     * Requirements:
     * - Prediction MUST exist.
     * - Current time MUST be >= expirationTime.
     * - Oracle price MUST fit into uint96.
     */
    function _resolvePrediction(address _prediction)
        internal
        virtual
        returns (bool isResolved)
    {
        Prediction storage p = predictions[_prediction];

        if (
            p.expirationTime <= block.timestamp && // time to resolve came
            p.resolvedPrice == 0 // implicit resolved flag
        ) {
            uint256 oraclePrice =
                IEnvelopOracle(ORACLE).getIndexPrice(_prediction);
            if (oraclePrice == 0) {
                oraclePrice =
                    IEnvelopOracle(ORACLE).getIndexPrice(p.portfolio);
            }
            
            if (oraclePrice > type(uint96).max) {
                revert OraclePriceTooHigh(oraclePrice);
            }

            p.resolvedPrice = uint96(oraclePrice);
            emit PredictionResolved(_prediction, oraclePrice);
        }
        isResolved = p.resolvedPrice > 0;
    }

    /// @dev Handles the "no-contest" case: if either YES or NO totalSupply is zero,
    ///      user gets their stake refunded for both sides they hold, and their 6909 shares are pulled back.
    /// @return isValidGame True if both sides have non-zero totalSupply.
    function _checkIsGameValidAndReturnStakesIfNot(address _user, address _prediction) internal returns (bool isValidGame){
        (uint256 yesToken, uint256 noToken) = hlpGet6909Ids(_prediction);
        isValidGame = totalSupply(yesToken) > 0 && totalSupply(noToken) > 0;
        CompactAsset storage s = predictions[_prediction].strike;

        //if we have bets only one side then no game situation
        //and users can get back their bets
        if (!isValidGame){
            uint256 y = balanceOf(_user, yesToken);
            uint256 n = balanceOf(_user, noToken);
            // 1. Pull back ERC6909 share tokens (not burned in this version)
            _transfer(_user, address(this), yesToken, y);
            // 1. Pull back ERC6909 share tokens (not burned in this version)
            _transfer(_user, address(this), noToken, n);

            // 2. Return original stake
            IERC20(s.token).safeTransfer(_user, y);
            IERC20(s.token).safeTransfer(_user, n);

        }
    }

    /**
     * @dev Claim the reward for a winning voter.
     *      Handles:
     *        - returning the original stake
     *        - pulling back 6909 share tokens
     *        - distributing fee to creator + protocol
     *        - paying remaining reward to user
     *
     * @param _user Address of the claimant.
     * @param _prediction Address of the prediction creator.
     */
    function _claim(address _user, address _prediction) internal {
        (
            uint256 winTokenId,
            uint256 winTokenBalance,
            ,
            uint256 winnerPrize
        ) = _getWinnerShareAndAmount(_user, _prediction);

        
        CompactAsset storage s = predictions[_prediction].strike;


        if (winnerPrize > 0) {
            uint256 paid;
            uint256 fee;    
            // 1. Pull back ERC6909 share tokens (not burned in this version)
            _transfer(_user, address(this), winTokenId, winTokenBalance);

            // 2. Return original stake
            IERC20(s.token).safeTransfer(_user, winTokenBalance);

            

            // 3. Creator fee
            fee =
                (winnerPrize * FEE_CREATOR_PERCENT * SCALE) /
                PERCENT_DENOMINATOR / SCALE;
            paid += fee;
            IERC20(s.token).safeTransfer(_prediction, fee);

            // 4. Protocol fee
            fee =
                (winnerPrize * FEE_PROTOCOL_PERCENT * SCALE) /
                PERCENT_DENOMINATOR / SCALE;
            paid += fee;
            IERC20(s.token).safeTransfer(FEE_PROTOCOL_BENEFICIARY, fee);

            // 5. User reward (winnerPrize minus all fees)
            uint256 userReward = winnerPrize - paid;
            IERC20(s.token).safeTransfer(_user, userReward);

            emit Claimed(_user, _prediction, userReward);
        }
    }

    /**
     * @dev Calculates:
     *        - tokenId of winning vote
     *        - user balance of winning tokens
     *        - user's share percentage (non-denominated)
     *        - total reward owed, proportional to losing pool
     *
     * @return winTokenId           ID of the winning ERC6909 token.
     * @return winTokenBalance      User balance of winning token.
     * @return sharesNonDenominated Fraction in PERCENT_DENOMINATOR units.
     * @return prizeAmount          Raw prize before fee splits.
     */
    function _getWinnerShareAndAmount(
        address _user,
        address _prediction
    )
        internal
        view
        returns (
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
            (uint256(uint160(_prediction)) << 96) |
            (predictedTrue ? 1 : 0);
        uint256 loserTokenId =
            (uint256(uint160(_prediction)) << 96) |
            (!predictedTrue ? 1 : 0);

        winTokenBalance = balanceOf(_user, winTokenId);

        // User share = userVotes / totalVotes
        uint256 totalWin = totalSupply(winTokenId);
        if (totalWin == 0) {
            return (winTokenId, 0, 0, 0);
        }

        sharesNonDenominated =
            (winTokenBalance * SCALE) /
            totalWin;

        // Prize = share * totalLosingPool
        uint256 totalLose = totalSupply(loserTokenId);
        prizeAmount =
            (totalLose * sharesNonDenominated) / SCALE;
    }
}
