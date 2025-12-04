// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {FundMe} from "../../src/FundMe.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {MockV3Aggregator} from "../mock/MockV3Aggregator.sol";

// Comprehensive set of unit tests that cover the happy + sad paths for FundMe.
contract FundMeTest is ZkSyncChainChecker, CodeConstants, StdCheats, Test {
    FundMe public fundMe;
    HelperConfig public helperConfig;

    uint256 public constant SEND_VALUE = 0.1 ether; // Consistent contribution used across tests so USD comparisons stay predictable.
    uint256 public constant STARTING_USER_BALANCE = 10 ether; // Ensures the USER prank address always has gas + principal to fund with.
    uint256 public constant GAS_PRICE = 1;

    uint160 public constant USER_NUMBER = 50;
    address public constant USER = address(USER_NUMBER);

    // uint256 public constant SEND_VALUE = 1e18;
    // uint256 public constant SEND_VALUE = 1_000_000_000_000_000_000;
    // uint256 public constant SEND_VALUE = 1000000000000000000;

    function setUp() external {
        // Use the same code path the scripts do unless we are running on zkSync where pipes differ.
        if (!isZkSyncChain()) {
            DeployFundMe deployer = new DeployFundMe();
            (fundMe, helperConfig) = deployer.deployFundMe();
        } else {
            // zkSync tests cannot use the DevOps helper, so spin up a local mock feed and inject it directly.
            MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
                DECIMALS,
                INITIAL_PRICE
            );
            fundMe = new FundMe(address(mockPriceFeed));
        }
        // Seed a helpful testing balance so we can prank/deal without repeated boilerplate.
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    // Confirms we stored the correct Chainlink feed address from HelperConfig during deployment.
    function testPriceFeedSetCorrectly() public skipZkSync {
        address retreivedPriceFeed = address(fundMe.getPriceFeed());
        // (address expectedPriceFeed) = helperConfig.activeNetworkConfig();
        address expectedPriceFeed = helperConfig
            .getConfigByChainId(block.chainid)
            .priceFeed;
        assertEq(retreivedPriceFeed, expectedPriceFeed);
    }

    // Expect a revert when someone tries to fund with 0 ETH (fails minimum USD check).
    function testFundFailsWithoutEnoughETH() public skipZkSync {
        vm.expectRevert(); // Without msg.value the MINIMUM_USD require should revert immediately.
        fundMe.fund();
    }

    // Contribution tracking should reflect the exact amount sent after a successful fund call.
    function testFundUpdatesFundedDataStructure() public skipZkSync {
        // Mimic a user connecting their wallet and sending value.
        vm.startPrank(USER); // All subsequent calls in this scope will have msg.sender = USER.
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    // We should append the new contributor to the funders array so the owner can reset them later.
    function testAddsFunderToArrayOfFunders() public skipZkSync {
        vm.startPrank(USER); // Force msg.sender for the array append path.
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    // https://twitter.com/PaulRBerg/status/1624763320539525121

    modifier funded() {
        // Common setup pattern for withdraw tests to guarantee the contract holds funds.
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    // Guard clause should stop any non-owner account from draining the contract.
    function testOnlyOwnerCanWithdraw() public funded skipZkSync {
        vm.expectRevert();
        vm.prank(address(3)); // Not the owner
        fundMe.withdraw();
    }

    // Happy path for a single funder - after withdraw everything ends up in the owner's wallet.
    function testWithdrawFromASingleFunder() public funded skipZkSync {
        // Arrange
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        // vm.txGasPrice(GAS_PRICE);
        // uint256 gasStart = gasleft();
        // // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // uint256 gasEnd = gasleft();
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;

        // Assert
        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance // + gasUsed
        );
    }

    // Can we do our withdraw function a cheaper way?
    // Stress test with multiple contributors to make sure the for-loop cleanup works properly.
    function testWithdrawFromMultipleFunders() public funded skipZkSync {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2 + USER_NUMBER;

        uint256 originalFundMeBalance = address(fundMe).balance; // This is for people running forked tests!

        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), STARTING_USER_BALANCE); // hoax seeds ETH + sets msg.sender so each synthetic wallet can call fund() once.
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundedeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundedeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );

        // Number of funders + whatever was already sitting in the contract prior to test run.
        uint256 expectedTotalValueWithdrawn = ((numberOfFunders) * SEND_VALUE) +
            originalFundMeBalance;
        uint256 totalValueWithdrawn = fundMe.getOwner().balance -
            startingOwnerBalance;

        assert(expectedTotalValueWithdrawn == totalValueWithdrawn);
    }
}
