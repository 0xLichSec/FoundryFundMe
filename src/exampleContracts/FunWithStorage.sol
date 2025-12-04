// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// Playground used by DeployFunWithStorage to study the EVM storage layout rules.
contract FunWithStorage {
    uint256 favoriteNumber; // Stored at slot 0 – takes full 32 bytes because it is a uint256.
    bool someBool; // Stored at slot 1 – occupies only 1 byte but the compiler still dedicates a whole slot because nothing else packs with it here.
    uint256[] myArray; /* Array length stored at slot 2,
        but the objects will be located at keccak256(2) because slot 2 is the dynamic array pointer slot by spec. */
    mapping(uint256 => bool) myMap; /* Slot 3 acts as the seed.
        Each element ends up at keccak256(abi.encode(key, uint256(3))) so we can practice verifying packing math manually. */
    uint256 constant NOT_IN_STORAGE = 123; // Constants/immutables live inside the contract bytecode, not the account storage trie.
    uint256 immutable i_not_in_storage; // Immutables are evaluated once in the constructor and stored in bytecode as well.

    constructor() {
        // Seed deterministic values so our storage inspection output is meaningful.
        favoriteNumber = 25; // See stored spot above // SSTORE
        someBool = true; // See stored spot above // SSTORE
        myArray.push(222); // SSTORE
        myMap[0] = true; // SSTORE
        i_not_in_storage = 123; // Stored once in bytecode so vm.load never surfaces it.
    }

    // Small function that exercises both SLOAD and stack-only variables so we can step through opcodes in a debugger.
    function doStuff() public {
        uint256 newVar = favoriteNumber + 1; // SLOAD
        bool otherVar = someBool; // SLOAD
        // ^^ memory / stack variables
    }
}
