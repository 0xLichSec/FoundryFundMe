// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {FundMe} from "../../src/FundMe.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {Test} from "forge-std/Test.sol";

contract FundMeTest is Test {
    FundMe public fundMe;

    // Spin up a bare FundMe pointing at Sepolia so we can test deployment plumbing fast.
    function setUp() public {
        // Hard-code the Sepolia ETH/USD feed address; this mimics what DeployFundMe would inject when targeting Sepolia.
        fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }

    // Sanity check to make sure the constructor actually stored the feed address we pass in.
    function testDeploy() public view {
        assertEq(
            address(fundMe.getPriceFeed()),
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        ); // Expectation: constructor stored the same feed address we passed in.
    }
}
