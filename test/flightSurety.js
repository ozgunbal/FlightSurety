
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSuretyData.registerAirline(config.firstAirline, {from: config.flightSuretyData.address})
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  /****************************************************************************************/
  /* Airlines                                                                             */
  /****************************************************************************************/

  it('(airline) cannot participate, if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineCanParticipate.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) can register an Airline using registerAirline() up to 4 airlines', async () => {
    
    // ARRANGE
    const secondAirline = accounts[2];
    const thirdAirline = accounts[3];
    const forthAirline = accounts[4];

    // ACT
    
    await config.flightSuretyApp.registerAirline(config.firstAirline, {from: config.owner});
    await config.flightSuretyData.fund({from: config.firstAirline, value: 10 * config.weiMultiple})
    await config.flightSuretyApp.registerAirline(secondAirline, {from: config.firstAirline});
    await config.flightSuretyApp.registerAirline(thirdAirline, {from: config.firstAirline});
    await config.flightSuretyApp.registerAirline(forthAirline, {from: config.firstAirline});

    const resultOne = await config.flightSuretyData.isAirlineRegistered.call(config.firstAirline);
    const resultTwo = await config.flightSuretyData.isAirlineRegistered.call(secondAirline); 
    const resultThree = await config.flightSuretyData.isAirlineRegistered.call(thirdAirline);
    const resultFour = await config.flightSuretyData.isAirlineRegistered.call(forthAirline);

    // ASSERT
    assert.equal(resultOne, true, "Airline should not be able to register another airline if it's not registered by owner");
    assert.equal(resultTwo, true, "Airline should not be able to register another airline if it's not registered by another registered airline");
    assert.equal(resultThree, true, "Airline should not be able to register another airline if it's not registered by another registered airline");
    assert.equal(resultFour, true, "Airline should not be able to register another airline if it's not registered by another registered airline");
  });

  it('(airline) can register an Airline using registerAirline() after 4 airlines in total with votes', async () => {
    
    // ARRANGE
    const secondAirline = accounts[2];
    const fifthAirline = accounts[5];

    // ACT
    await config.flightSuretyApp.registerAirline(fifthAirline, {from: config.firstAirline});

    const resultOne = await config.flightSuretyData.isAirlineRegistered.call(fifthAirline);

    // ASSERT
    assert.equal(resultOne, false, "Airline should not be able to register another airline if it has enough votes from other airlines");
    
    // ACT
    // secondAirline first add funds to be able to call registerAirline()
    // then add another vote to fifthAirline and its vote would be 2/4 then it's registered
    await config.flightSuretyData.fund({from: secondAirline, value: 10 * config.weiMultiple });
    await config.flightSuretyApp.registerAirline(fifthAirline, {from: secondAirline});
    const resultTwo = await config.flightSuretyData.isAirlineRegistered.call(fifthAirline);

    // ASSERT
    assert.equal(resultTwo, true, "Airline should not be able to register another airline if it has enough votes from other airlines");
  });
 
  it('(passenger) can buy an insurance and can withdraw credit', async () => {
    
    // ARRANGE
    let flight = 'ND1309'; // Course number
    let timestamp = Math.floor(Date.now() / 1000);

    // ACT
    // For test purposes only
    await config.flightSuretyData.authorizeCaller(config.owner, {from: config.owner});

    const flightKey = await config.flightSuretyData.testOnlyGetFlightKey(config.firstAirline, flight, timestamp);
    await config.flightSuretyData.buy(config.owner, config.firstAirline, flightKey, {from: config.owner, value: 1 * config.weiMultiple });

    await config.flightSuretyData.pay(flightKey, config.firstAirline, 150, {from: config.owner});

    // console.log('Withdrawable: ', result.toNumber());
    await config.flightSuretyApp.creditInsurees({from: config.owner});
  });

});
