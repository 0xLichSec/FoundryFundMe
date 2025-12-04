// SPDX-License-Identifier: MIT
// 1. Pragma
pragma solidity 0.8.19;

// 2. Imports
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

// 3. Interfaces, Libraries, Contracts
error FundMe__NotOwner();

/**
 * @title A sample Funding Contract
 * @author Patrick Collins
 * @notice This contract is for creating a sample funding contract
 * @dev This implements price feeds as our library
 */
contract FundMe {
    // Type Declarations
    using PriceConverter for uint256;

    // State variables
    uint256 public constant MINIMUM_USD = 5 * 10 ** 18; // Enforces ~$5 minimum contributions using 18 decimals so it is comparable to msg.value math.
    address private immutable i_owner; // Records the deployer once during construction so owner-only functions can trust this immutable reference.
    address[] private s_funders; // Append-only list of every contributor, used to zero out mappings deterministically on withdraw.
    mapping(address => uint256) private s_addressToAmountFunded; // Tracks total ETH funded per address so the UI + accounting can surface balances.
    AggregatorV3Interface private s_priceFeed; // Chainlink price feed interface injected at deployment to support different networks/mocks.

    // Events (we have none!)

    // Modifiers
    modifier onlyOwner() {
        // require(msg.sender == i_owner);
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    // Functions Order:
    //// constructor
    //// receive
    //// fallback
    //// external
    //// public
    //// internal
    //// private
    //// view / pure

    constructor(address priceFeed) {
        // Dependency injection means we can swap in mocks during tests or local runs.
        s_priceFeed = AggregatorV3Interface(priceFeed);
        i_owner = msg.sender;
    }

    /// @notice Funds our contract based on the ETH/USD price
    function fund() public payable {
        // Convert the incoming ETH amount into USD terms and block the tx if it fails to clear the $5 threshold.
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "You need to spend more ETH!"
        );
        // require(PriceConverter.getConversionRate(msg.value) >= MINIMUM_USD, "You need to spend more ETH!");
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender); // Duplicate entries are fine; withdraw loop just zeroes everything
    }

    // aderyn-ignore-next-line(centralization-risk,unused-public-function,state-change-without-event))
    function withdraw() public onlyOwner {
        // aderyn-ignore-next-line(storage-array-length-not-cached,costly-loop)
        // Reset everyone's contribution before pulling funds so fresh rounds start cleanly. This loop writes 0 to each funder's mapping slot to prevent stale balances.
        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        // Transfer vs call vs Send
        // payable(msg.sender).transfer(address(this).balance);
        // Use call to forward all gas + capture the success flag, which is the current best practice for pulling ETH out of a contract.
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    // Same logic as `withdraw` but loads funders array into memory for a slight gas discount.
    function cheaperWithdraw() public onlyOwner {
        // Pull the storage array into memory so we only warm the slot once.
        address[] memory funders = s_funders;
        // mappings can't be in memory, sorry!
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        // payable(msg.sender).transfer(address(this).balance);
        // Same call pattern as withdraw() so behaviour stays consistent even though storage reads differ.
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    /**
     * Getter Functions
     */

    /**
     * @notice Gets the amount that an address has funded
     *  @param fundingAddress the address of the funder
     *  @return the amount funded
     */
    function getAddressToAmountFunded(
        address fundingAddress
    ) public view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getVersion() public view returns (uint256) {
        // Helpful for debugging – surfaces the Chainlink aggregator version so scripts confirm they are pointing at expected deployment.
        return s_priceFeed.version();
    }

    function getFunder(uint256 index) public view returns (address) {
        // Exposes the nth funder so external callers can iterate without accessing storage directly.
        return s_funders[index];
    }

    function getOwner() public view returns (address) {
        // Owner exposes up-to-date withdraw authority so front-ends can warn if ownership changes.
        return i_owner;
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        // Allows tests + scripts to confirm what feed address the contract trusts right now.
        return s_priceFeed;
    }
}
