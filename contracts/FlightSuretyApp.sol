pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract
    FlightSuretyData dataContract;          // To interact with Data contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 leavesAt;
        uint256 updatedAt;
        address airline;
    }
    mapping(string => Flight) private flights;

    //Mapping to keep track of multi-party consensus.
        //Key -> Address to be a new airline
        //Value --> Array containing airlines that voted to register 'key' address as a new airline
    mapping(address =>  address[]) multiCalls;


    event FlightRegistered(string flight);
 
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
        require(dataContract.isOperational(), "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner(){
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier validAddress(address addr){
        require(addr != address(0), "Address must be valid.");
        _;
    }

    modifier flightDoesntExist(string flight){
        require(!flights[flight].isRegistered, "A flight with that indentifier already exists. Try a new one.");
        _;
    }

    modifier flightExists(string flight){
        require(flights[flight].isRegistered, "The is no flight with provided identifier. Make sure you sent the correct identifier.");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor (address dataContractAddress) public {
        //Deployer is the owner
        contractOwner = msg.sender;
        //Link to data contract is done on deployment
        dataContract = FlightSuretyData(dataContractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns(bool) {
        return dataContract.isOperational();
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline( address newAirline  ) external requireIsOperational validAddress(newAirline) returns(bool success, uint256 votes) {
        require(dataContract.isAirline(msg.sender), "Sender must be a registered Airline");
        require(dataContract.isParticipatingAirline(msg.sender), "Sender must have funded at least 10 ether");
        require(!dataContract.isAirline(newAirline), "The proposed address is already a registered airline");


        //How many airlines are there?
        uint airlinesCount = dataContract.getAirlinesAmount();
        //If there are less than four, add a new one
        if(airlinesCount < 4){
            dataContract.registerAirline(newAirline);
            success = true;
            return (success, 0);
        //If there are four or more airlines, multi-party consensus applies
        }else{
            //Check if it's a duplicated vote
            bool isDuplicate = false;
            if(multiCalls[newAirline].length == 0 ){
                multiCalls[newAirline] = new address[](0);
            }
            for( uint c = 0 ; c < multiCalls[newAirline].length ; c++ ) {
                if (multiCalls[newAirline][c] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }
            require(!isDuplicate, "Caller has already voted for this address");

            //Add the vote
            multiCalls[newAirline].push(msg.sender);
            //50% of participating airlines must vote to add a new airline
            uint M = uint (dataContract.getParticipatingAirlinesAmount()).div(2);
            if (multiCalls[newAirline].length >= M) {
                delete multiCalls[newAirline];
                dataContract.registerAirline(newAirline);
                success = true;
            }else{
                success = false;
            }
            //Return status and number of votes
            return (success, multiCalls[newAirline].length);
        }
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight ( string flightName, uint timeStamp ) public requireIsOperational flightDoesntExist(flightName) returns (string){
        require(dataContract.isAirline(msg.sender), "Sender must be a registered Airline");
        require(dataContract.isParticipatingAirline(msg.sender), "Sender must have funded at least 10 ether");

        flights[flightName] = Flight({
            isRegistered: true,
            statusCode: STATUS_CODE_UNKNOWN,
            leavesAt: timeStamp,
            updatedAt: block.number,
            airline: msg.sender});

        emit FlightRegistered(flightName);
        return flightName;
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus (address airline, string flight, uint256 timestamp, uint8 statusCode)
        internal requireIsOperational flightExists(flight){

        require(dataContract.isAirline(airline), "Airline provided must be an airline!");
        require(dataContract.isParticipatingAirline(airline), "Airline provided haven't fund yet!");

        flights[flight].statusCode = statusCode;
        flights[flight].updatedAt = timestamp;

        if(statusCode == STATUS_CODE_LATE_AIRLINE){
            dataContract.creditInsurees(flight);
        }

    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline,string flight,uint256 timestamp) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 4;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request, or request is already closed");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
            //Added: close request afer first response is validated
            oracleResponses[key].isOpen = false;

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);
            
            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

contract FlightSuretyData{
    function isOperational() external view returns(bool);
    function isAirline(address airline) public view returns(bool);
    function isParticipatingAirline(address airline) public view returns(bool);
    function setOperatingStatus (bool mode) external;
    function registerAirline ( address airlineAddress ) external;
    function creditInsurees ( string flightKey ) external;
    function getAirlinesAmount() public view returns (uint256);
    function getParticipatingAirlinesAmount() public view returns (uint256);
}
