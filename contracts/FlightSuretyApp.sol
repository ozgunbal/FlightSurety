// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

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

    uint256 private constant ACCEPTABLE_VOTE_PERCENTAGE = 50;

    uint256 private constant INSURANCE_MULTIPLIER = 150; // This will be divided to 100 during computation

    address private contractOwner;          // Account used to deploy contract
    IFlightSuretyData fligtSuretyData;       // Data contract instance

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    
    struct Votes {
        uint256 voteCount;
        mapping(address => uint8) voters;
    }
    mapping(address => Votes) private airlineVotes;


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
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires that the sender airline is registered
    */
    modifier requireRegisteredAirline() {
        require(fligtSuretyData.isAirlineRegistered(msg.sender), "Caller is not registered airline");
        _;
    }

    /**
    * @dev Modifier that requires that the sender airline can participate or the sender is contract owner for only to add first airline
    */
    modifier requireCanRegisterAirline() {
        uint airlineCount = fligtSuretyData.getAirlineCount();
        require(fligtSuretyData.isAirlineCanParticipate(msg.sender) || ((msg.sender == contractOwner) && (airlineCount == 0)), 'Caller should be registered airline or contract owner for first registration');
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContract
                                ) 
    {
        fligtSuretyData = IFlightSuretyData(dataContract);
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            pure 
                            returns(bool) 
    {
        return true;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (
                                address _airlineAddress   
                            )
                            external
                            requireCanRegisterAirline
                            returns(bool success, uint256 votes)
    {
        uint airlineCount = fligtSuretyData.getAirlineCount();
        if (airlineCount < 4) {
            fligtSuretyData.registerAirline(_airlineAddress);
            return (true, 0);
        } else {
            return _voteAirline(_airlineAddress);
        }
    }

    /**
    * @dev Vote an airline for registration
    *
    */
    function _voteAirline (address _airlineAddress) private requireRegisteredAirline returns(bool success, uint256 votes) {
        require(airlineVotes[_airlineAddress].voters[msg.sender] == 0, 'Caller already voted for this airline');
        
        airlineVotes[_airlineAddress].voteCount += 1;
        airlineVotes[_airlineAddress].voters[msg.sender] = 1;
        
        uint256 voteCount = airlineVotes[_airlineAddress].voteCount;
        uint airlineCount = fligtSuretyData.getAirlineCount();
        uint256 percentage = (voteCount.mul(100)).div(airlineCount);
        bool hasEnoughVote = percentage >= ACCEPTABLE_VOTE_PERCENTAGE;

        if (hasEnoughVote) {
            fligtSuretyData.registerAirline(_airlineAddress);
            return (true, voteCount);
        } else {
            return (false, voteCount);
        }
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp
                                )
                                external
                                payable
    {
        require(msg.value <= 1 ether, 'Flight insurance should be less than or equal to 1 ether');
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        Flight memory newFlight;
        newFlight.isRegistered = true;
        newFlight.updatedTimestamp = timestamp;
        newFlight.airline = airline;
        flights[flightKey] = newFlight;

        fligtSuretyData.buy{value: msg.value}(msg.sender, airline, flightKey);
    }

    function creditInsurees () external {
        fligtSuretyData.creditInsurees(msg.sender);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
    {
        
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        bool hasStatus = flights[flightKey].airline == airline && flights[flightKey].updatedTimestamp == timestamp && flights[flightKey].statusCode == statusCode;
        if (!hasStatus) {
            flights[flightKey].updatedTimestamp = timestamp;
            flights[flightKey].statusCode = statusCode;
            flights[flightKey].airline = airline;

            if (statusCode == STATUS_CODE_LATE_AIRLINE) {
                fligtSuretyData.pay(flightKey, airline, INSURANCE_MULTIPLIER);
            }
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string calldata flight,
                            uint256 timestamp                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));

        ResponseInfo storage newResponse = oracleResponses[key];
        newResponse.requester = msg.sender;
        newResponse.isOpen = true;

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


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
                            returns(uint8[3] memory)
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
                            string memory flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
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
                            returns(uint8[3] memory)
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
        uint8 random;
        unchecked {
            random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);   
        }

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

interface IFlightSuretyData {
    function registerAirline(address airlineAddress) external;
    function isAirlineRegistered(address airlineAddress) external returns (bool);
    function isAirlineCanParticipate(address airlineAddress) external returns (bool);
    function getAirlineCount () external view returns (uint256);
    function buy (address insuree, address airline, bytes32 flightKey) external payable;
    function pay (bytes32 flightKey, address airline, uint256 multiplier) external;
    function creditInsurees (address insuree) external;
}