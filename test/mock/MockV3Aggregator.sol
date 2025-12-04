// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockV3Aggregator
 * @notice Based on the FluxAggregator contract
 * @notice Use this contract when you need to test
 * other contract's ability to read data from an
 * aggregator contract, but how the aggregator got
 * its answer is unimportant
 */
contract MockV3Aggregator is AggregatorV3Interface {
    uint256 public constant version = 4;

    uint8 public decimals; // Mirrors the production feed decimals so FundMe math stays identical in tests.
    int256 public latestAnswer; // Tracks the head price just like the Chainlink aggregator contract.
    uint256 public latestTimestamp; // Stores when the price was last updated so consumers can assert freshness.
    uint256 public latestRound; // Incrementing round id that mimics Chainlink round sequencing.

    mapping(uint256 => int256) public getAnswer; // RoundID => answer mapping, needed for historic lookups.
    mapping(uint256 => uint256) public getTimestamp; // RoundID => updatedAt timestamp, same format Chainlink uses.
    mapping(uint256 => uint256) private getStartedAt; // RoundID => startedAt timestamp; matches AggregatorV3Interface expectations.

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals; // Align decimals with whichever live feed we are trying to impersonate (Sepolia uses 8).
        updateAnswer(_initialAnswer); // Seed deterministic price data so tests begin with a realistic USD value.
    }

    // Simple helper we can call from tests to simulate price changes.
    function updateAnswer(int256 _answer) public {
        latestAnswer = _answer;
        latestTimestamp = block.timestamp;
        latestRound++;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = block.timestamp;
        getStartedAt[latestRound] = block.timestamp;
    }

    // Used when tests want to emulate the aggregator syncing older round data.
    function updateRoundData(
        uint80 _roundId,
        int256 _answer,
        uint256 _timestamp,
        uint256 _startedAt
    ) public {
        latestRound = _roundId;
        latestAnswer = _answer;
        latestTimestamp = _timestamp;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = _timestamp;
        getStartedAt[latestRound] = _startedAt;
    }

    // Interfaces expect this exact signature so FundMe can request historical rounds.
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
        )
    {
        return (
            _roundId,
            getAnswer[_roundId],
            getStartedAt[_roundId],
            getTimestamp[_roundId],
            _roundId
        );
    }

    // Latest data accessor mirrors the real Chainlink aggregator behaviour.
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            uint80(latestRound),
            getAnswer[latestRound],
            getStartedAt[latestRound],
            getTimestamp[latestRound],
            uint80(latestRound)
        );
    }

    function description() external pure returns (string memory) {
        return "v0.6/test/mock/MockV3Aggregator.sol";
    }
}
