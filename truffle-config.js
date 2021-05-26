require("babel-register");
require("babel-polyfill");
require("dotenv").config();
const { PRIVATEKEY, BSCSCANAPIKEY } = process.env;

const HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */
  plugins: ["truffle-plugin-verify"],
  api_keys: {
    bscscan: BSCSCANAPIKEY,
  },

  networks: {
    // development: {
    //   host: "127.0.0.1", // Localhost (default: none)
    //   port: 8545, // Standard BSC port (default: none)
    //   network_id: "*", // Any network (default: none)
    // },
    testnet: {
      provider: () =>
        new HDWalletProvider(
          [PRIVATEKEY],
          `https://data-seed-prebsc-1-s1.binance.org:8545`
        ),
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 300000,
      skipDryRun: true,
    },
    bsc: {
      provider: () =>
        new HDWalletProvider([PRIVATEKEY], `https://bsc-dataseed1.binance.org`),
      network_id: 56,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true,
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.7.6", // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {
        // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: false,
          runs: 200,
        },
        evmVersion: "byzantium",
      },
    },
  },
};
