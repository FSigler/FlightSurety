import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import { SSL_OP_EPHEMERAL_RSA } from 'constants';
require('babel-polyfill');

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);


  let REGISTRATION_FEE = web3.utils.toWei("1", "ether");
  
  let oracles = [];
  let oracleIndexes = new Map();

  const loadOracles = async () => {
    console.log("Registering oracles...");
    oracles = (await web3.eth.getAccounts()).slice(20,50);
    
    oracles.forEach(async (oracle, index) => {
      await flightSuretyApp.methods
      .registerOracle()
      .send({from: oracle, value: REGISTRATION_FEE, gas: 5000000 ,gasPrice: 100000000000});

      let indexes = await flightSuretyApp.methods
      .getMyIndexes()
      .call({from: oracle});

      oracleIndexes.set(oracle, indexes);

      console.log(`Oracle registered: ${oracle}. Indexes: ${indexes[0]}, ${indexes[1]}, ${indexes[2]}`);
      
      //After last oracle is registered, we start the listeners
      if(index == 29){
        console.log('Oracles registered.');
        eventListeners();
      } 

    });

  }

  const eventListeners = () => {

    console.log('Setting up event listeners...');

    flightSuretyData.events.InsuranceBought({
      //fromBlock: 0
    }, function (error, event) {
      if (error) console.log(error)
      //console.log(event)
      let data = event.returnValues;
      console.log(`Event: ${event.event}. Insuree: ${data.insuree}. Flight: ${data.flight}. Value: ${data.value}`);
    });

    flightSuretyApp.events.OracleRequest({
        //fromBlock: 0
      }, function (error, event) {
        if (error) console.log(error)
        //console.log(event)
        let data = event.returnValues;
        console.log(`Event: ${event.event}. Index: ${data.index}. Flight: ${data.flight}. Timestamp: ${data.timestamp}`);
        //console.log(` '-Data: ${JSON.stringify(data, null, '\t')}`);
        responseRequest(data);
      });

    flightSuretyApp.events.OracleReport({
      //fromBlock: 0
    }, function (error, event) {
      if (error) console.log(error)
      //console.log(event)
      //let data = event.returnValues;
      //console.log(`Event: ${event.event}. Flight: ${data.flight}. Status: ${data.status}.`);
      //console.log(` '-Data: ${JSON.stringify(data, null, '\t')}`);
    });

    flightSuretyApp.events.FlightStatusInfo({
      //fromBlock: 0
    }, function (error, event) {
      if (error) console.log(error)
      //console.log(event)
      let data = event.returnValues;
      console.log(`Event: ${event.event}. Flight: ${data.flight}. Status: ${data.status}.`);
    });

    console.log('Event listeners set up.');

  }

  const responseRequest = async (data) => {
    let statusCodes = [0,10,20,30,40,50,20, 20, 20, 20];
    let rand = Math.round(Math.random()*9);
    let statusCode = statusCodes[rand];
    //Check on all oracles 
    let indexes = [];
    oracles.forEach(async (oracle, arrayIndex) => {
      // if request index match one of their indexes
      try{
        indexes = oracleIndexes.get(oracle);
        if(indexes[0] == data.index || indexes[1] == data.index || indexes[2] == data.index ){
          console.log(`Index match for oracle ${arrayIndex}! Submit response!`);
          //Submit a response  
          await flightSuretyApp.methods
            .submitOracleResponse(data.index, data.airline, data.flight, data.timestamp, statusCode)
            .send({from: oracle, gas: 5000000 ,gasPrice: 100000000000});
        }
      }catch(e){
        console.log(`Exception caught! : ${e}`);
      }
    });
  }

  const main = async () => {
    await loadOracles();
  }

  main();


const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


