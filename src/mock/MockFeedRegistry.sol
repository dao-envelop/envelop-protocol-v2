// test/mocks/MockFeedRegistry.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FeedRegistryInterface} from "../../src/utils/EnvelopOracle.sol"; //  FeedRegistryInterface

contract MockFeedRegistry is FeedRegistryInterface {
    struct FeedData {
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
        uint8 decimals;
        uint80 roundId;
    }

    // base => quote => FeedData
    mapping(address => mapping(address => FeedData)) public feeds;

    function setFeed(
        address base,
        address quote,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 roundId,
        uint80 answeredInRound,
        uint8 _decimals
    ) external {
        feeds[base][quote] = FeedData({
            answer: answer,
            startedAt: startedAt,
            updatedAt: updatedAt,
            answeredInRound: answeredInRound,
            decimals: _decimals,
            roundId: roundId
        });
    }

    function latestRoundData(
        address base,
        address quote
    )
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        FeedData memory d = feeds[base][quote];
        return (d.roundId, d.answer, d.startedAt, d.updatedAt, d.answeredInRound);
    }

    function decimals(address base, address quote)
        external
        view
        override
        returns (uint8)
    {
        return feeds[base][quote].decimals;
    }
}
