// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => uint256) private authorizedCallers;              // Authorized FlightSuretyApp contracts(callers)            
    
    struct AirlineProfile {
        bool isRegistered;
        bool canParticipate;
        address airlineAddress;
        uint fundAmount;
    }

    mapping(address => AirlineProfile) private airlines;
    uint private airlineCount = 0;

    struct InsureesInsurance {
        uint initialAmount;
        address insureeAddress;
    }

    struct FlightInsurance {
        address airlineAddress;
        InsureesInsurance[] insurees;
        uint insureeCount;    
    }

    mapping(bytes32 => FlightInsurance) private flightInsurances;
    mapping(address => uint) private withdrawableInsurances;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                )
    {
        contractOwner = msg.sender;
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
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
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
    * @dev Modifier that requires the Authorized caller account to be the function caller
    */
    modifier requireCallerAuthorized()
    {
        require(authorizedCallers[msg.sender] == 1, "Caller is not authorized");
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
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /**
    * @dev Adds an authorized contract(caller)
    *
    * Enables to critical data manipulation can be only done by authorized callers
    */
    function authorizeCaller
                            (
                                address callerAddress
                            )
                            external
                            requireContractOwner
    {
        authorizedCallers[callerAddress] = 1;
    }

    /**
    * @dev Removes an authorized contract(caller)
    *
    * It might need when FlightSuretyApp changes and old contract should be deathorized
    */
    function deauthorizeCaller
                            (
                                address callerAddress
                            )
                            external
                            requireContractOwner
    {
        delete authorizedCallers[callerAddress];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                address _airlineAddress
                            )
                            external
                            requireIsOperational
                            requireCallerAuthorized
    {
        AirlineProfile memory airline;
        airline.isRegistered = true;
        airline.airlineAddress = _airlineAddress;
        airlines[_airlineAddress] = airline;
        airlineCount = airlineCount + 1;
    }

    function isAirlineRegistered (address _airlineAddress) external view returns (bool) {
        return airlines[_airlineAddress].isRegistered;
    }

    function isAirlineCanParticipate (address _airlineAddress) external view returns (bool) {
        return airlines[_airlineAddress].canParticipate;
    }

    function getAirlineCount () external view returns (uint256) {
        return airlineCount;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (     
                                address insuree,
                                address airline,
                                bytes32 flightKey                        
                            )
                            external
                            payable
                            requireIsOperational
                            requireCallerAuthorized
    {
        if (flightInsurances[flightKey].insureeCount == 0) {
            flightInsurances[flightKey].airlineAddress = airline;
            flightInsurances[flightKey].insureeCount += 1;
            flightInsurances[flightKey].insurees.push(
                InsureesInsurance({
                    insureeAddress: insuree,
                    initialAmount: msg.value
                })
            );
        } else {
            flightInsurances[flightKey].insureeCount += 1;
            flightInsurances[flightKey].insurees.push(
                InsureesInsurance({
                    insureeAddress: insuree,
                    initialAmount: msg.value
                })
            );
        }

        airlines[airline].fundAmount += msg.value;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (address insuree)
                                external
                                requireIsOperational
                                requireCallerAuthorized
    {
        require(withdrawableInsurances[insuree] > 0, "There's nothing to withdraw");
        uint amount = withdrawableInsurances[insuree];
        delete withdrawableInsurances[insuree];
        payable(insuree).transfer(amount);
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                bytes32 flightKey,
                                address airline,
                                uint256 multiplier
                            )
                            external
                            requireIsOperational
                            requireCallerAuthorized
    {
        FlightInsurance memory flightInsurance =  flightInsurances[flightKey];

        for(uint i=0; i < flightInsurance.insureeCount; i++) {
            uint withdrawAmount = (flightInsurance.insurees[i].initialAmount.mul(multiplier)).div(100);
            airlines[airline].fundAmount -= withdrawAmount;
            withdrawableInsurances[flightInsurance.insurees[i].insureeAddress] += withdrawAmount; 
        }
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
                            requireIsOperational
    {
        require(airlines[msg.sender].isRegistered, 'Caller cannot fund, if it is not a registered airline');
        require(msg.value == 10 ether);
        airlines[msg.sender].fundAmount = msg.value;
        airlines[msg.sender].canParticipate = true;
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

    function testOnlyGetFlightKey(
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        public
                        view
                        requireCallerAuthorized
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    receive()
                            external 
                            payable
    {
        fund();
    }


}

