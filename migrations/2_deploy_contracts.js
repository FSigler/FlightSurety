const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');
const FUND_TAX = web3.utils.toWei("10", "ether");

module.exports = async function(deployer) {
    
    deployer.deploy(FlightSuretyData)
    .then(async(data) => {
        //Deployer, which is the first airline, also pays the funds needed during contract migration.
        await data.fund({value: FUND_TAX});
        //console.log(`I am printing the address of the deployed DATA Smart Contract ${data.address}`);
        return deployer.deploy(FlightSuretyApp, data.address)
                .then(async(app) => {
                    //Once app is deployed, owner authorizes app contract to use data contract
                    await data.authorizeContract(app.address);

                    //After airline funding, app deployed and authorized, airline registers five flights
                    let flights = [];
                    let flightNames = [
                        "AFQM-Udacity-BCND001",
                        "AFQM-Udacity-BCND002",
                        "AFQM-Udacity-BCND003",
                        "AFQM-Udacity-BCND004",
                        "AFQM-Udacity-BCND005"
                    ];
                    let timestamp = Math.floor((Date.now()+ 60*60*1000) / 1000);

                    flights[0] = await app.registerFlight(flightNames[0], timestamp);
                    flights[1] = await app.registerFlight(flightNames[1], timestamp);
                    flights[2] = await app.registerFlight(flightNames[2], timestamp);
                    flights[3] = await app.registerFlight(flightNames[3], timestamp);
                    flights[4] = await app.registerFlight(flightNames[4], timestamp);

                    //Config file to be used from server and dapp
                    let config = {
                        localhost: {
                            url: 'http://localhost:9545',
                            dataAddress: FlightSuretyData.address,
                            appAddress: FlightSuretyApp.address
                        },
                        flights: flightNames
                    }
                    fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                    fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                });
    });
}