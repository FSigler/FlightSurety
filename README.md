# FlightSurety

FlightSurety is a sample application project (Project 4) for Udacity's Blockchain course.

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle develop`

## Develop Client

To run truffle tests, inside truffle develop console:

`truffle(develop)> test`

To use the dapp:

1. Truffle develop terminal:
`truffle(develop)> compile`
`truffle(develop)> migrate --reset`
2. New terminal:
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`npm run server`

## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)