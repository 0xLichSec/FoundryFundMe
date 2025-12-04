// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// Mini helper library so FundMe can keep math tidy and centralize every assumption around Chainlink feed decimals.
library PriceConverter {
    // Returns ETH price in USD with 18 decimals so it lines up with msg.value units.
    function getPrice(
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        // Chainlink ETH/USD answers ship with 8 decimals; multiply by 1e10 so returned value aligns to 1e18 style wei math.
        return uint256(answer * 10000000000);
    }

    // Converts an ETH amount to its USD value using the Chainlink price feed data.
    function getConversionRate(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        // Divide by 1e18 (aka 1 ether) so the math works for arbitrary msg.value inputs rather than being hard-coded.
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000;
        // the actual ETH/USD conversation rate, after adjusting the extra 0s.
        return ethAmountInUsd;
    }
}
