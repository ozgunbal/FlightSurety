const FlightSuretyApp = require('../../build/contracts/FlightSuretyApp.json');
const Config = require('./config.json');
const Web3 = require('web3');
const express = require('express');

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url));
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
flightSuretyApp.options.gas = 2000000

let accounts;
let oracleAccounts;
const registeredOracles = [];
const initialOracleAccountIndex = 20;
const TEST_ORACLES_COUNT = 20;

const setAccounts = async () => {
  accounts = await web3.eth.getAccounts();
  oracleAccounts = accounts.slice(initialOracleAccountIndex);
  web3.eth.defaultAccount = accounts[0];
}

const registerOracles = async () => {
  await setAccounts();
  console.log('Registration of Oracles...');
  
  const fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
  
  for(let a=0; a<TEST_ORACLES_COUNT; a++) {
    await flightSuretyApp.methods.registerOracle().send({ from: oracleAccounts[a], value: fee });
    let result = await flightSuretyApp.methods.getMyIndexes().call({from: oracleAccounts[a]});
    console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    registeredOracles.push({
      oracleAddress: oracleAccounts[a],
      indexes: [result[0], result[1], result[2]]
    })
  }
}

flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function async (error, event) {
    if (error) console.log(error)
    const {index, airline, flight, timestamp} = event.returnValues
    const filteredOracles = registeredOracles.filter(oracle => {
      return oracle.indexes[0] === index || oracle.indexes[1] === index || oracle.indexes[2] === index
    });
    const statusCode = Math.floor(Math.random() * 6) * 10;
    filteredOracles.forEach(oracle => {
      flightSuretyApp.methods.submitOracleResponse(index, airline, flight, timestamp, statusCode).send({ from: oracle.oracleAddress });
    })
});

registerOracles();

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

module.exports = app


