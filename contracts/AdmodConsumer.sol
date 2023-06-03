// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract AdmodConsumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    // the earning amount of this week
    uint256 public earning;

    bytes32 private jobId;
    uint256 private fee;

    /** @beneficiary: An 0xSplits contract that has 1 Gnosis contract as Controller of it
    * In this 0xSplits contract will contain the list of charity organizations' addresses
    */
    address public beneficiary;

    event RequestEarning(bytes32 indexed requestId, uint256 earning);

    /**
     * @notice Initialize the link token and target oracle
     *
     * Sepolia Testnet details:
     * Link Token: 0x779877A7B0D9E8603169DdbD7836e478b4624789
     * Oracle: 0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD (Chainlink DevRel)
     * jobId: ca98366cc7314957b8c012c72f05aeeb
     *
     */
    constructor(address _beneficiary) ConfirmedOwner(beneficiary) {
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
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

    /**
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

    /**
     * Allow withdraw of Link tokens from the contract
     @notice: LINK will always be sent to beneficiary 0xSplits contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(beneficiary, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

}