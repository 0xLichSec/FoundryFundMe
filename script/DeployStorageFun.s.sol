// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {FunWithStorage} from "../src/exampleContracts/FunWithStorage.sol";

contract DeployFunWithStorage is Script {
    // Handy utility for deploying the storage playground contract and dumping its storage layout.
    function run() external returns (FunWithStorage) {
        // Broadcast the transaction exactly like a user would so vm.load reads production-accurate slots.
        // startBroadcast ensures the deployment transaction uses the private key configured for forge script, matching real deployments.
        vm.startBroadcast();
        FunWithStorage funWithStorage = new FunWithStorage();
        vm.stopBroadcast();
        // Immediately inspect storage so we can learn how Solidity laid things out for this exact deployment.
        printStorageData(address(funWithStorage));
        printFirstArrayElement(address(funWithStorage));
        return (funWithStorage);
    }

    // Reads the first few storage slots so we can correlate code ↔ slot.
    function printStorageData(address contractAddress) public view {
        // Iterate through the first ten storage slots since that is enough to cover all state vars in FunWithStorage.
        for (uint256 i = 0; i < 10; i++) {
            // vm.load peeks directly into the storage slot without executing contract code, so we can map slot -> value exactly.
            bytes32 value = vm.load(contractAddress, bytes32(i));
            console.log("Value at location", i, ":");
            console.logBytes32(value);
        }
    }

    // Shows how to compute the dynamic array storage slot manually.
    function printFirstArrayElement(address contractAddress) public view {
        // Slot 2 holds the dynamic array length; hashing that slot per the Solidity spec yields the base slot of the array elements.
        bytes32 arrayStorageSlotLength = bytes32(uint256(2));
        bytes32 firstElementStorageSlot = keccak256(
            abi.encode(arrayStorageSlotLength)
        );
        bytes32 value = vm.load(contractAddress, firstElementStorageSlot);
        console.log("First element in array:");
        console.logBytes32(value);
    }

    // Option 1
    /*
     * cast storage ADDRESS
     */

    // Option 2
    // cast k 0x0000000000000000000000000000000000000000000000000000000000000002
    // cast storage ADDRESS <OUTPUT_OF_ABOVE>

    // Option 3:
    /*
     * curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"debug_traceTransaction","params":["0xe98bc0fd715a075b83acbbfd72b4df8bb62633daf1768e9823896bfae4758906"],"id":1}' http://127.0.0.1:8545 > debug_tx.json
     * Go through the JSON and find the storage slot you want
     */

    // You could also replay every transaction and track the `SSTORE` opcodes... but that's a lot of work
}
