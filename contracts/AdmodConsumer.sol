// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract AdmodConsumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    // the earning amount of this week
    uint256 public earning;

    bytes32 private jobId;
    uint256 private fee;

    /** 
     * @notice
     * @beneficiary: An 0xSplits contract that has 1 Gnosis contract as Controller of it
     * In this 0xSplits contract will contain the list of charity organizations' addresses
     */
    address public beneficiary;

    event RequestEarning(bytes32 indexed requestId, uint256 earning);

    /**
     * @notice Initialize the link token and target oracle
     *
     * Mumbai Testnet details:
     * Link Token: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB
     * Oracle: 0xaA37473c8d78F0f1C86c9d8aEE53E8B896bCB4D5 
     * jobId: b1d42cd54a3a4200b1f725a68e488888
     *
     */
    constructor(address _owner, address _beneficiary) ConfirmedOwner(_owner) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xaA37473c8d78F0f1C86c9d8aEE53E8B896bCB4D5);
        jobId = "b1d42cd54a3a4200b1f725a68e488888";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
        beneficiary = _beneficiary;
    }

     /**
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function requestWeekEarning() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        // Set the URL to perform the GET request on
        req.add(
            "get",
            "https://testapi.io/api/Hayden/v1/accounts/pub-9988776655443322/networkReport"
        );

        req.add("path", "row,metricValues,ESTIMATED_EARNINGS,microsValue");

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    /** @notice
     * Receive the response in the form of uint256
     */
    function fulfill(
        bytes32 _requestId,
        uint256 _earning
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestEarning(_requestId, _earning);
        /** 
        @notice earning will be a total of earning this week subtract for Transak transaction fee
        */
        earning = _earning;
    }

    /** @notice
     * Allow withdraw of Link tokens from the contract
     * LINK will always be sent to beneficiary 0xSplits contract
     */

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(beneficiary, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}