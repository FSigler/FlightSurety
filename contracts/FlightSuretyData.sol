pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    
    mapping(address => uint8) private authorizedContracts;              //Authorized App Contracts
    mapping(address => bool) private airlines;                          //Registered Airlines
    mapping(address => bool) private airlinesParticipating;             //Airlines which funded at least 10 ether
    mapping(address => uint256) private funds;                          //How much has each airline funded
    uint256 private airlinesAmount;                                     //Count the amount of airlines (wether they funded or not)
    uint256 private participatingAirlinesAmount;                        //Count the amount of participating airlines

    struct Insurance{
        address insuree;
        uint256 value;
    }
    mapping(string => Insurance[]) insurances;                          //flghtkeys =>  insurances
    mapping(address => uint256) credits;                                //Customer => owed from insurances
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event Fund(uint amount, address airline);
    event AirlineAdded(address airline);
    event AirlineCompletedFund(address airline);
    event InsuranceBought(address insuree, string flight, uint value);
    event Credited(address insuree, uint value);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor (   ) public {
        contractOwner = msg.sender;
        //Deployer is registered as the first airline
        airlines[msg.sender] = true;
        airlinesAmount = 1;

        /*If first airline didn't require funding
        airlinesParticipating[msg.sender] = true;
        participatingAirlinesAmount = 1;
        */

        emit AirlineAdded(msg.sender);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedContract() {
        require(authorizedContracts[msg.sender] == 1, "Caller is not authorized");
        _;
    }

    modifier validAddress(address addr){
        require(addr != address(0), "Address must be valid.");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view returns(bool) {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus (bool mode) external requireContractOwner {
        require(mode != operational, "New mode must be different from existing mode");
        operational = mode;
    }

    function authorizeContract ( address contractAddress ) external requireContractOwner validAddress(contractAddress){
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeContract ( address contractAddress ) external requireContractOwner validAddress(contractAddress){
        delete authorizedContracts[contractAddress];
    }

    function isAirline(address airline) public view returns(bool) {
        return airlines[airline];
    }

    function isParticipatingAirline(address airline) public view returns(bool) {
        return airlinesParticipating[airline];
    }

    function getAirlinesAmount() public view returns (uint256) {
        return airlinesAmount;
    }

    function getParticipatingAirlinesAmount() public view returns (uint256) {
        return participatingAirlinesAmount;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline ( address airlineAddress ) external requireIsOperational requireAuthorizedContract validAddress(airlineAddress){
        airlines[airlineAddress] = true;
        airlinesAmount = airlinesAmount.add(1);
        emit AirlineAdded(airlineAddress);

        /* If first four airlines didn't require funding
        if(participatingAirlinesAmount < 4){
            airlinesParticipating[airlineAddress] = true;
            participatingAirlinesAmount = participatingAirlinesAmount.add(1);
        }
        */
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy (string flightKey ) external payable requireIsOperational{
        require(msg.value <= 1 ether, "Insurances can be bought up to 1 ether only");
        insurances[flightKey].push(Insurance({insuree: msg.sender, value: msg.value}));
        emit InsuranceBought(msg.sender, flightKey, msg.value);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees ( string flightKey ) external requireAuthorizedContract requireIsOperational{
        uint256 debt = 0;
        address insuree = (0x0);
        uint count = insurances[flightKey].length;
        //The amount to be credited is 1.5 times the amount payed to buy the insurance
        for(uint i = 0; i < count; i++){
            debt = insurances[flightKey][i].value.mul(3).div(2);
            insuree = insurances[flightKey][i].insuree;
            insurances[flightKey][i].value = 0;
            credits[insuree] = credits[insuree].add(debt);
            delete insurances[flightKey][i];
            emit Credited(insuree, debt);
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay ( ) external{
        require(credits[msg.sender]>0, "There are no pending credits to pay");
        uint256 debt = credits[msg.sender];
        credits[msg.sender] = 0;
        msg.sender.transfer(debt);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund (   ) public payable{
        require(isAirline(msg.sender), "Funder must be a registered airline");
        require(msg.value > 0, "Must send ether to fund");
        //The following requires could potentially prevent the contract from being funded (excect by adding more airlines, making them fund in order to participate)
        //require(msg.value <= 10 ether, "Participating tax is 10 ether");
        //require(funds[msg.sender]<10 ether, "You already paid the participating tax");
        funds[msg.sender] = funds[msg.sender].add(msg.value);
        //When an airline reach 10 ether fund, they can participate on app smart contract
        if(funds[msg.sender] >= 10 ether && !airlinesParticipating[msg.sender]){
            airlinesParticipating[msg.sender] = true;
            //participatingAirlinesAmount++ but using SafeMath;
            participatingAirlinesAmount = participatingAirlinesAmount.add(1);
            emit AirlineCompletedFund(msg.sender);
        }
        emit Fund(msg.value, msg.sender);
    }

    function getFlightKey (address airline, string flight, uint256 timestamp) internal pure  returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
        fund();
    }


}

