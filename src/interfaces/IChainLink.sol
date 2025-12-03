// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV2V3Interface.sol";

/// @title Chainlink Aggregator V2 Interface
/// @notice Legacy interface for Chainlink price feeds (pre-AggregatorV3).
/// @dev V2 feeds support basic accessors for latest answer, timestamp,
///      historical rounds, and round metadata. Newer feeds may not support V2,
///      so prefer using AggregatorV3Interface where available.
interface AggregatorInterface {
    /**
     * @notice Returns the latest price answer.
     * @dev The returned value may have its own decimals; consumers must know them externally.
     * @return The most recently reported price answer.
     */
    function latestAnswer() external view returns (int256);

    /**
     * @notice Returns timestamp of the latest round.
     * @return Timestamp of the last update.
     */
    function latestTimestamp() external view returns (uint256);

    /**
     * @notice Returns the latest round ID.
     * @dev Round IDs increase monotonically.
     * @return The latest round identifier.
     */
    function latestRound() external view returns (uint256);

    /**
     * @notice Returns the price answer for a specific round.
     * @param roundId Round identifier to query.
     * @return Price answer for the given round.
     */
    function getAnswer(uint256 roundId) external view returns (int256);

    /**
     * @notice Returns the timestamp of a specific round.
     * @param roundId Round identifier to query.
     * @return Timestamp when the round was updated.
     */
    function getTimestamp(uint256 roundId) external view returns (uint256);

    /// @notice Emitted whenever a new answer is recorded.
    /// @param current The newly reported price.
    /// @param roundId The round in which the update occurred.
    /// @param updatedAt Timestamp when it was updated.
    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

    /// @notice Emitted when a new round is started.
    /// @param roundId Identifier of the new round.
    /// @param startedBy Address that initiated the round.
    /// @param startedAt Timestamp when the round was started.
    event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

/// @title Chainlink Aggregator V3 Interface
/// @notice Modern interface for Chainlink price feeds with full round metadata.
/// @dev ALWAYS prefer using AggregatorV3Interface when available.
///      It guarantees consistent structure and safer use.
interface AggregatorV3Interface {

    /**
     * @notice Returns the number of decimals used by the price.
     * @dev Consumers must use this for correct normalization.
     * @return Decimals of the aggregator answer.
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Human-readable feed description (e.g., "ETH/USD").
     * @return Description string.
     */
    function description() external view returns (string memory);

    /**
     * @notice Returns version of the aggregator contract.
     * @return Version identifier.
     */
    function version() external view returns (uint256);

    /**
     * @notice Returns round data for a specific round ID.
     * @dev Will revert if round is not complete.
     * @param _roundId The round ID you want to query.
     * @return roundId Returned round id.
     * @return answer Price for that round.
     * @return startedAt Timestamp when the round started.
     * @return updatedAt Timestamp when the round reported an answer.
     * @return answeredInRound Round ID in which the answer was actually computed.
     */
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    /**
     * @notice Returns data for the latest round.
     * @dev Will revert if no data available.
     * @return roundId Latest round id.
     * @return answer Latest price.
     * @return startedAt Timestamp when round started.
     * @return updatedAt Timestamp when it updated.
     * @return answeredInRound Round in which answer was computed.
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/// @title Combined Chainlink Aggregator V2/V3 interface
/// @notice This interface is implemented by all modern Chainlink aggregators.
/// @dev Allows using both V2 and V3 style methods depending on feed capabilities.
interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface {}



/// @title Chainlink Feed Registry Interface
/// @notice Interface for interacting with the Chainlink Feed Registry,
///         which maps (base, quote) asset pairs to their corresponding
///         Aggregator contracts and provides price and round metadata.
///
/// @dev This interface supports both Aggregator V2 and V3 style accessors,
///      as well as phase management and proposed feeds. It is intended to be
///      used with the deployed Feed Registry contracts on supported networks.
///
///      Important:
///      - `base` and `quote` can be ERC-20 token addresses or special
///        "denomination" addresses (e.g., USD, ETH, BTC) defined by Chainlink.
///      - For denomination constants, see Chainlink Denominations:
///        https://docs.chain.link/data-feeds/reference/denominations
interface FeedRegistryInterface {
    // ================================================================
    //                             STRUCTS
    // ================================================================

    /// @notice Represents a phase of an aggregator for a given (base, quote) pair.
    /// @dev Each phase corresponds to a specific underlying aggregator contract
    ///      and a contiguous range of round IDs.
    struct Phase {
        uint16 phaseId;
        uint80 startingAggregatorRoundId;
        uint80 endingAggregatorRoundId;
    }

    // ================================================================
    //                             EVENTS
    // ================================================================

    /// @notice Emitted when a new feed (aggregator) is proposed for a given (base, quote) pair.
    /// @param asset The base asset of the price pair.
    /// @param denomination The quote asset of the price pair.
    /// @param proposedAggregator Address of the newly proposed aggregator.
    /// @param currentAggregator Address of the currently active aggregator (may be zero).
    /// @param sender Address that proposed the feed update.
    event FeedProposed(
        address indexed asset,
        address indexed denomination,
        address indexed proposedAggregator,
        address currentAggregator,
        address sender
    );

    /// @notice Emitted when a proposed feed is confirmed and becomes active.
    /// @param asset The base asset of the price pair.
    /// @param denomination The quote asset of the price pair.
    /// @param latestAggregator Address of the activated aggregator.
    /// @param previousAggregator Address of the previously active aggregator.
    /// @param nextPhaseId The phase ID that the new aggregator will use.
    /// @param sender Address that confirmed the feed update.
    event FeedConfirmed(
        address indexed asset,
        address indexed denomination,
        address indexed latestAggregator,
        address previousAggregator,
        uint16 nextPhaseId,
        address sender
    );

    // ================================================================
    //                     V3 Aggregator Interface
    // ================================================================

    /**
     * @notice Returns the number of decimals for the price of (base, quote).
     * @dev This decimals value should be used to normalize the `answer` in
     *      `latestRoundData` or `getRoundData`.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return The number of decimals for the price.
     */
    function decimals(
        address base,
        address quote
    ) external view returns (uint8);

    /**
     * @notice Returns the description string of the price feed for (base, quote).
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return Human-readable description for the feed.
     */
    function description(
        address base,
        address quote
    ) external view returns (string memory);

    /**
     * @notice Returns the version number of the feed for (base, quote).
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return Version of the underlying aggregator contract.
     */
    function version(
        address base,
        address quote
    ) external view returns (uint256);

    /**
     * @notice Returns the latest round data for the (base, quote) pair.
     * @dev This is the V3-style accessor combining round ID, price, and timestamps.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return roundId The round ID.
     * @return answer The latest price for (base, quote).
     * @return startedAt Timestamp when this round started.
     * @return updatedAt Timestamp when this round was last updated.
     * @return answeredInRound The round ID in which the answer was computed.
     */
    function latestRoundData(
        address base,
        address quote
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    /**
     * @notice Returns data for a specific round ID for the (base, quote) pair.
     * @dev This is the V3-style accessor. Useful for historical pricing and auditing.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param _roundId The round ID to query.
     * @return roundId The round ID (may differ in composed phase/round ID encoding).
     * @return answer The price answer for that round.
     * @return startedAt Timestamp when the round started.
     * @return updatedAt Timestamp when the round was last updated.
     * @return answeredInRound The round ID in which the answer was computed.
     */
    function getRoundData(
        address base,
        address quote,
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    // ================================================================
    //                     V2 Aggregator Interface
    // ================================================================

    /**
     * @notice Returns the latest price answer for (base, quote).
     * @dev This is the V2-style simple accessor. Prefer using latestRoundData where possible.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return answer The latest price answer.
     */
    function latestAnswer(
        address base,
        address quote
    ) external view returns (int256 answer);

    /**
     * @notice Returns the timestamp of the latest round for (base, quote).
     * @dev V2-style accessor.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return timestamp The timestamp of the latest round.
     */
    function latestTimestamp(
        address base,
        address quote
    ) external view returns (uint256 timestamp);

    /**
     * @notice Returns the latest round ID for (base, quote).
     * @dev V2-style accessor.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return roundId The latest round ID.
     */
    function latestRound(
        address base,
        address quote
    ) external view returns (uint256 roundId);

    /**
     * @notice Returns the price answer for a specific round for (base, quote).
     * @dev V2-style accessor.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param roundId The round ID.
     * @return answer The price answer for that round.
     */
    function getAnswer(
        address base,
        address quote,
        uint256 roundId
    ) external view returns (int256 answer);

    /**
     * @notice Returns the timestamp of a specific round for (base, quote).
     * @dev V2-style accessor.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param roundId The round ID.
     * @return timestamp The timestamp for the given round.
     */
    function getTimestamp(
        address base,
        address quote,
        uint256 roundId
    ) external view returns (uint256 timestamp);

    // ================================================================
    //                        Registry getters
    // ================================================================

    /**
     * @notice Returns the active aggregator contract for (base, quote).
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return aggregator The AggregatorV2V3Interface instance for the pair.
     */
    function getFeed(
        address base,
        address quote
    ) external view returns (AggregatorV2V3Interface aggregator);

    /**
     * @notice Returns the aggregator contract for a specific phase for (base, quote).
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param phaseId The phase ID.
     * @return aggregator The AggregatorV2V3Interface instance for that phase.
     */
    function getPhaseFeed(
        address base,
        address quote,
        uint16 phaseId
    ) external view returns (AggregatorV2V3Interface aggregator);

    /**
     * @notice Checks if a given aggregator address is enabled in the registry.
     * @param aggregator Address of the aggregator contract.
     * @return True if the aggregator is enabled, false otherwise.
     */
    function isFeedEnabled(
        address aggregator
    ) external view returns (bool);

    /**
     * @notice Returns Phase metadata for a given (base, quote, phaseId).
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param phaseId The phase ID.
     * @return phase The Phase struct describing the phase.
     */
    function getPhase(
        address base,
        address quote,
        uint16 phaseId
    ) external view returns (Phase memory phase);

    // ================================================================
    //                         Round helpers
    // ================================================================

    /**
     * @notice Returns the aggregator contract that served a given round.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param roundId The global round ID (across phases).
     * @return aggregator The AggregatorV2V3Interface that served this round.
     */
    function getRoundFeed(
        address base,
        address quote,
        uint80 roundId
    ) external view returns (AggregatorV2V3Interface aggregator);

    /**
     * @notice Returns the starting and ending round IDs for a specific phase.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param phaseId The phase ID.
     * @return startingRoundId The first round ID in this phase.
     * @return endingRoundId The last round ID in this phase.
     */
    function getPhaseRange(
        address base,
        address quote,
        uint16 phaseId
    ) external view returns (uint80 startingRoundId, uint80 endingRoundId);

    /**
     * @notice Returns the previous round ID before a given round.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param roundId The reference round ID.
     * @return previousRoundId The previous round ID.
     */
    function getPreviousRoundId(
        address base,
        address quote,
        uint80 roundId
    ) external view returns (uint80 previousRoundId);

    /**
     * @notice Returns the next round ID after a given round.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param roundId The reference round ID.
     * @return nextRoundId The next round ID.
     */
    function getNextRoundId(
        address base,
        address quote,
        uint80 roundId
    ) external view returns (uint80 nextRoundId);

    // ================================================================
    //                         Feed management
    // ================================================================

    /**
     * @notice Proposes a new aggregator for (base, quote) pair.
     * @dev Only callable by authorized admin roles in the official registry.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param aggregator Address of the proposed aggregator contract.
     */
    function proposeFeed(
        address base,
        address quote,
        address aggregator
    ) external;

    /**
     * @notice Confirms and activates a previously proposed aggregator for (base, quote).
     * @dev Only callable by authorized admin roles in the official registry.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param aggregator Address of the aggregator contract to confirm.
     */
    function confirmFeed(
        address base,
        address quote,
        address aggregator
    ) external;

    // ================================================================
    //                       Proposed aggregators
    // ================================================================

    /**
     * @notice Returns the currently proposed (but not yet confirmed) aggregator for (base, quote).
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return proposedAggregator The proposed AggregatorV2V3Interface instance.
     */
    function getProposedFeed(
        address base,
        address quote
    ) external view returns (AggregatorV2V3Interface proposedAggregator);

    /**
     * @notice Returns round data from the proposed aggregator for (base, quote).
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @param roundId Round ID on the proposed aggregator.
     * @return id The round ID.
     * @return answer The price answer.
     * @return startedAt Timestamp when the round started.
     * @return updatedAt Timestamp when the round was last updated.
     * @return answeredInRound The round in which the answer was computed.
     */
    function proposedGetRoundData(
        address base,
        address quote,
        uint80 roundId
    )
        external
        view
        returns (
            uint80 id,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    /**
     * @notice Returns the latest round data from the proposed aggregator for (base, quote).
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return id The round ID.
     * @return answer The latest price answer.
     * @return startedAt Timestamp when the round started.
     * @return updatedAt Timestamp when it was last updated.
     * @return answeredInRound The round ID in which the answer was computed.
     */
    function proposedLatestRoundData(
        address base,
        address quote
    )
        external
        view
        returns (
            uint80 id,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    // ================================================================
    //                              Phases
    // ================================================================

    /**
     * @notice Returns the current phase ID for a given (base, quote) pair.
     * @param base Base asset address.
     * @param quote Quote asset address.
     * @return currentPhaseId The current phase ID.
     */
    function getCurrentPhaseId(
        address base,
        address quote
    ) external view returns (uint16 currentPhaseId);
}
