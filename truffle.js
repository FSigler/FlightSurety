//var HDWalletProvider = require("truffle-hdwallet-provider");

module.exports = {
  networks: {
    //We configure the 'truffle develop' network
    develop: {
      accounts: 50,
      defaultEtherBalance: 500,
      host: "127.0.0.1",
      port: 9545, //Truffle develop command runs a private ETH network like ganache, but on port 9545 instead
      network_id: "*" // Match any network id
    }
    /*
    development: {
      accounts: 50,
      defaultEtherBalance: 500,
      host: "127.0.0.1",
      port: 9545, //Truffle develop command runs a private ETH network like ganache, but on port 9545 instead
      network_id: "*" // Match any network id
    }
    */
  },
  compilers: {
    solc: {
      version: "^0.4.25"
    }
  }
};