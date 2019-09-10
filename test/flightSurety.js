//This package is used for blockchain event assertions.
const truffleAssert = require('truffle-assertions');

// Declare a variable and assign the compiled smart contract artifact
const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");

//instances of contracts
let instance = {};
//'truffle develop' test accounts: 10 accounts
let accounts;

//Wait until all contracts have been deployed.
contract('FlightSuretyApp', async (accs) => {
    //We fill the accounts var to use them
    accounts = accs;
    instance.app = await FlightSuretyApp.deployed();
});

contract('FlightSuretyData', async (accs) => {
    instance.data = await FlightSuretyData.deployed();
});

//Deployed is both: A) owner of the contracts, & B) first airplane
let owner = accounts[0]; 
//First four airlines to be added
let airlines = [accounts[0], accounts[1], accounts[2], accounts[3]];
//Fifth airlined to be added via multi-party
let toBeVotedAirline = accounts[4];
//Customer to buy an insurance
let insuree = accounts[5];
//Tax to fund contract (airlines must pay to participate)
const FUND_TAX = web3.utils.toWei("10", "ether");


//Tests begin
it('[Operational] App is operational after deployment', async() => {
    //Wait until instance is there. Weird because of Async, 
    //but it may be undefined at first and affect other tests too.
    for(let i = 0; i<100000000;i++){
        if(instance.app != undefined){
            assert.isTrue( await instance.app.isOperational() );
            break;
        }
    }
});

it(`[Operational] Block access to setOperatingStatus() for non-Contract Owner account`, async function () {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
        await instance.data.setOperatingStatus(false, { from: insuree });
    }catch(e) {
        accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");     
});

it('[Authorization] Owner authorize APP contract to access DATA contract', async() => {
    //Wait until instance is there.
    for(let i = 0; i<100000000;i++){
        if(instance.data != undefined){
            await instance.data.authorizeContract(instance.app.address, {from: owner}) ;
            break;
        }
    }
});

it('[Airlines] Owner is first airline', async() => {
    assert.isTrue(await instance.data.isAirline(owner));
});

it('[Airlines] First airline funds its payment to be a participating airline', async() => {
    let participatingAirlinesAmount = await instance.data.getParticipatingAirlinesAmount();
    if(participatingAirlinesAmount == 0){
        let tx = await instance.data.fund({from:airlines[0], value: FUND_TAX});
        truffleAssert.eventEmitted(tx, 'AirlineCompletedFund', (ev) => {
            return (ev.airline == airlines[0]);
        });
        truffleAssert.eventEmitted(tx, 'Fund', (ev) => {
            return (ev.amount == FUND_TAX && ev.airline == airlines[0]);
        });
        //There should be just '1' participating airlines
        participatingAirlinesAmount = await instance.data.getParticipatingAirlinesAmount();
        assert.equal(1, participatingAirlinesAmount);
        //airlines[0] should be a participaing airline now
        assert.isTrue(await instance.data.isParticipatingAirline(airlines[0]));
    }
});

it('[Airlines] First airline adds three more airlines', async() => {
    for(let i = 1; i<airlines.length;i++){
        await instance.app.registerAirline(airlines[i],{from: airlines[0]});
        assert.isTrue(await instance.data.isAirline(airlines[i]));
    }
});

it('[Airlines] Airlines cannot register an Airline using registerAirline() if it is not funded', async () => {
    try {
        await instance.app.registerAirline(toBeVotedAirline, {from: airlines[1]});
    }catch(e) {

    }
    let result = await instance.data.isAirline(toBeVotedAirline); 
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");
});

it('[Airlines] Three airlines previously added fund their payments to be participating airlines', async() => {
    let participatingAirlinesAmount = await instance.data.getParticipatingAirlinesAmount();
    if( participatingAirlinesAmount < 4){
        //Second airline
        let tx = await instance.data.fund({from:airlines[1], value: FUND_TAX});
        truffleAssert.eventEmitted(tx, 'AirlineCompletedFund', (ev) => {
            return (ev.airline == airlines[1]);
        });
        truffleAssert.eventEmitted(tx, 'Fund', (ev) => {
            return (ev.amount == FUND_TAX && ev.airline == airlines[1]);
        });
        assert.isTrue(await instance.data.isParticipatingAirline(airlines[1]));

        //Third airline
        let tx2 = await instance.data.fund({from:airlines[2], value: FUND_TAX});
        truffleAssert.eventEmitted(tx2, 'AirlineCompletedFund', (ev) => {
            return (ev.airline == airlines[2]);
        });
        truffleAssert.eventEmitted(tx2, 'Fund', (ev) => {
            return (ev.amount == FUND_TAX && ev.airline == airlines[2]);
        });
        assert.isTrue(await instance.data.isParticipatingAirline(airlines[2]));

        //Fourth airline
        let tx3 = await instance.data.fund({from:airlines[3], value: FUND_TAX});
        truffleAssert.eventEmitted(tx3, 'AirlineCompletedFund', (ev) => {
            return (ev.airline == airlines[3]);
        });
        truffleAssert.eventEmitted(tx3, 'Fund', (ev) => {
            return (ev.amount == FUND_TAX && ev.airline == airlines[3]);
        });
        assert.isTrue(await instance.data.isParticipatingAirline(airlines[3]));
        
        //Check amount
        participatingAirlinesAmount = await instance.data.getParticipatingAirlinesAmount();
        assert.equal(4, participatingAirlinesAmount);
    }
});

it('[Multi-Party] Airline three and four (50% of participating) add a fifth airline', async() => {
    assert.isFalse(await instance.data.isAirline(toBeVotedAirline));
    await instance.app.registerAirline(toBeVotedAirline,{from: airlines[2]});
    assert.isFalse(await instance.data.isAirline(toBeVotedAirline));
    await instance.app.registerAirline(toBeVotedAirline,{from: airlines[3]});
    assert.isTrue(await instance.data.isAirline(toBeVotedAirline));
});

it('[Airlines] Fifth airline cannot participate until funding.', async() => {
    try {
        await instance.app.registerAirline(insuree, {from: toBeVotedAirline});
    }catch(e) {

    }
    assert.isFalse(await instance.data.isAirline(insuree), "Airline should not be able to register another airline if it hasn't provided funding");
});

it('', async() => {

});
