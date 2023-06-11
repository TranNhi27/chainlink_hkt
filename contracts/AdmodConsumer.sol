// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 

contract AdmodConsumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    using SafeMath for uint;

    // Chainlink Automation's Upkeep contract
    address public upkeep;

    // the earning amount of this week
    uint256 public earning;

    // the amount of LINK bought from Transak with $earning amount
    uint256 public linkAmount;
 
    // 2 separate jobId for google AdmodAPI and TransakAPI
    bytes32 public ggJobId;
    bytes32 public transakJobId;

    uint256 private fee;

    /** 
     * Save this week earningReport if the status of the contract is still active
     * => isEligible == true
     */
    mapping(uint256 => uint256) public earningReports;

    /** 
     * @notice
     * @isEligible: The important variable to judge the reliability of the contract
     * if isEligible == true => the current status of the contract is transparent
     * else isEligible == false => malicious actions have been made to the contract; or the mobile Application
     */
    bool public isEligible;

    // only Chainlink's Upkeep is allowed 
    modifier onlyUpkeep {
        require(msg.sender == upkeep, "Sender is not Upkeep");
        _;
    }

    /** 
     * @notice
     * @beneficiary: An 0xSplits contract that has 1 Gnosis contract as Controller of it
     * In this 0xSplits contract will contain the list of charity organizations' addresses
     */
    address public beneficiary;

    /** 
     * @notice
     * @nonce: this is required for 0xSplits contract because after each distribution
     * the contract will leave 1 Link wei to prevent overflow
     */
    uint256 public nonce;

    event RequestEarning(bytes32 indexed requestId, uint256 earning);
    event RequestBoughtAmount(bytes32 indexed requestId, uint256 linkAmount);


    /**
     * @notice Initialize the link token and target oracle
     *
     * Mumbai Testnet details:
     * Link Token: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB
     * Oracle: 0xaA37473c8d78F0f1C86c9d8aEE53E8B896bCB4D5 
     * ggJobId: b1d42cd54a3a4200b1f725a68e488888
     * transakJobId: b1d42cd54a3a4200b1f725a68e488999
     * Upkeep: 0x3931703419Fc456Cd48157497166550493C92448
     */
    constructor(address _owner, address _beneficiary) ConfirmedOwner(_owner) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xaA37473c8d78F0f1C86c9d8aEE53E8B896bCB4D5);
        ggJobId = "b1d42cd54a3a4200b1f725a68e488888";
        transakJobId = "b1d42cd54a3a4200b1f725a68e488999";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
        beneficiary = _beneficiary;
        isEligible = true;
        upkeep = address(0x3931703419Fc456Cd48157497166550493C92448);
    }

     /**
     * Create a Chainlink request to retrieve Google Admod API response,
     * fetch the earning this week,
     */
    function requestWeekEarning() public onlyUpkeep returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            ggJobId,
            address(this),
            this.fulfill.selector
        );

        // testapi following Google Admod API structure
        req.add(
            "get",
            "https://testapi.io/api/Hayden27/v1/accounts/pub-9988776655443322/networkReport"
        );

        req.add("path", "row,metricValues,ESTIMATED_EARNINGS,microsValue");

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    /** @notice
     * Receive the response's earning in the form of uint256
     */
    function fulfill(
        bytes32 _requestId,
        uint256 _earning
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestEarning(_requestId, _earning);

        earning = _earning;
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        // The contract will update 0xSplit beneficiary contract balance here 
        // it would be in form of LINK wei
        nonce = link.balanceOf(beneficiary);
        _requestTransakValidation();
    }

    // Send a request to Transak API to fetch LINK amount = Earning this week
    function _requestTransakValidation() private returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            transakJobId,
            address(this),
            this.fulfillTransakPrice.selector
        );

        // Get the real Earning since Earning from Google is in microsValue
        // E.g: 165320000 = 165.32$
        uint256 headEarning = SafeMath.div(earning,1000000);
        uint256 tailEarning = SafeMath.mod(earning,1000000);

        string memory apiUrl = string(abi.encodePacked("https://api.transak.com/api/v2/currencies/price?partnerApiKey=80250c2b-316a-4168-8328-56299dabfe00&fiatCurrency=USD&cryptoCurrency=LINK&isBuyOrSell=BUY&network=ethereum&paymentMethod=credit_debit_card&fiatAmount=",
        Strings.toString(headEarning),".",Strings.toString(tailEarning)));

        // Set the URL to perform the GET request on
        req.add(
            "get",
            apiUrl
        );

        req.add("path", "response,cryptoAmount");
        req.addUint("times", LINK_DIVISIBILITY);

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    // Oracle fulfill the Transak Request
    function fulfillTransakPrice(
        bytes32 _requestId,
        uint256 _linkAmount
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestBoughtAmount(_requestId, _linkAmount);
        // Update LINK amount buyable 
        linkAmount = _linkAmount;
        // Check if the LINK amount equals 0xSplit beneficiary contract balance
        _checkEligibleEarning();
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

    function _checkEligibleEarning() private {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        /** @notice
        * beneficiaryBalance = linkAmount + nonce
        * because after every distribution to Split's recipents 0xSplit contract 
        * will leave 1 LINK Wei to prevent overflow
         */
        uint256 beneficiaryBalance = SafeMath.add(linkAmount, nonce);
        if (beneficiaryBalance == link.balanceOf(beneficiary))
        {
            // If balance of beneficiary = beneficiaryBalance => isEligible = true
            earningReports[block.number] = earning;
            isEligible = true;
        }
        else isEligible = false;
    }

}