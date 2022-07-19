import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.config = config;
        this.web3 = new Web3(new Web3.providers.WebsocketProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyApp.options.gas = 2000000
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
        
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            // Only for demo purposes normally contract owner should call authorize elsewhere, not in the UI that passenger uses
            this.flightSuretyData.methods.authorizeCaller(this.config.appAddress).send({from: this.owner});

            callback();
        });

        // Register flights by calling the contract
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(airline, flight, timestamp, callback) {
        let self = this;
        let payload = {
            airline,
            flight,
            timestamp,
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    submitInsurance(airline, flight, timestamp, amount, callback) {
        let self = this;
        let payload = {
            airline,
            flight,
            timestamp,
            amount,
        }
        self.flightSuretyApp.methods
            .registerFlight(payload.airline, payload.flight, payload.timestamp)
            .send({from: self.owner, value: this.web3.utils.toWei(amount, 'ether')}, (error, result) => {
                callback(error, payload);
            }); 
    }

    withdrawInsurance(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .creditInsurees()
            .send({from: self.owner}, (error, result) => {
                callback(error, result);
            }); 
    }

    listenFlightInfo(callback) {
        let self = this;
        self.flightSuretyApp.events.FlightStatusInfo(function (error, event) {
            if (error) console.log('ERROR: ' , error);
            callback(event.returnValues);
        })
    }
}