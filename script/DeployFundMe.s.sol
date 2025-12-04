// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {FundMe} from "../src/FundMe.sol";

contract DeployFundMe is Script {
    // Main helper so we can spin up FundMe with the right supporting contracts in a single call.
    function deployFundMe() public returns (FundMe, HelperConfig) {
        // Instantiate HelperConfig so we can fetch the right Chainlink feed or deploy mocks depending on block.chainid.
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        // Resolve the price feed address up front to keep constructor args explicit and auditable.
        address priceFeed = helperConfig
            .getConfigByChainId(block.chainid)
            .priceFeed;

        // Broadast the deployment transaction using the resolved price feed for this chain, ensuring FundMe references the same feed tests expect.
        vm.startBroadcast();
        FundMe fundMe = new FundMe(priceFeed);
        vm.stopBroadcast();
        return (fundMe, helperConfig);
    }

    // Standard Foundry entry point that scripts call via `forge script`; surfaces deployments + configs to tests.
    function run() external returns (FundMe, HelperConfig) {
        return deployFundMe();
    }
}
