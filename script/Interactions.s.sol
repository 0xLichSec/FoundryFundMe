// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract FundFundMe is Script {
    uint256 SEND_VALUE = 0.1 ether; // Hard-coded contribution so scripts demonstrate a typical supporter deposit end-to-end.

    // Helper that automates sending a deposit to the latest FundMe deployment.
    function fundFundMe(address mostRecentlyDeployed) public {
        // Use startBroadcast so the transaction is signed/broadcast like a real user interaction and not a cheatcode shortcut.
        vm.startBroadcast();
        FundMe(payable(mostRecentlyDeployed)).fund{value: SEND_VALUE}();
        vm.stopBroadcast();
        console.log("Funded FundMe with %s", SEND_VALUE);
    }

    // Lookup the latest address stored by DevOpsTools, then fund it.
    function run() external {
        // DevOpsTools caches deployment addresses by contract name + chain id, which lets us script interactions without hand-copying addresses.
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "FundMe",
            block.chainid
        );
        fundFundMe(mostRecentlyDeployed);
    }
}

contract WithdrawFundMe is Script {
    // Mirrors FundFundMe but performs the owner withdrawal instead.
    function withdrawFundMe(address mostRecentlyDeployed) public {
        // Broadcasts as the private key owner configured for forge script, so the withdraw call must obey the FundMe owner checks.
        vm.startBroadcast();
        FundMe(payable(mostRecentlyDeployed)).withdraw();
        vm.stopBroadcast();
        console.log("Withdraw FundMe balance!");
    }

    function run() external {
        // Pull the freshest deployment so withdrawals always target the most recently broadcast FundMe for this chain.
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "FundMe",
            block.chainid
        );
        withdrawFundMe(mostRecentlyDeployed);
    }
}
