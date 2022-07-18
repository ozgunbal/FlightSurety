const HDWalletProvider = require('@truffle/hdwallet-provider');

const fs = require('fs');
const mnemonic =  "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat" // fs.readFileSync(".secret").toString().trim();
// const infuraKey = fs.readFileSync(".infuraKey").toString().trim();

module.exports = {

  networks: {
    development: {
        host: "127.0.0.1",
        port: 7545,
        network_id: "*", // Match any network id
        websockets: true
    }

    /* rinkeby: {
      provider: function() {
        return new HDWalletProvider(mnemonic, `https://rinkeby.infura.io/v3/${infuraKey}`);
      },
      network_id: '4',
      gas: 5500000,        // rinkeby has a lower block limit than mainnet
    }, */
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "^0.8.0",
    }
  }
}
