/** @type import('hardhat/config').HardhatUserConfig */
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();
module.exports = {
  networks: {
    hardhat: {},
    mumbai: {
      url: "https://polygon-testnet-rpc.allthatnode.com:8545",
      accounts: [process.env.PRI_KEY],
    },
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 40000,
  },
  etherscan: {
    apiKey: "STEUE1JHTQZPPZFRFN5UI2XX3J13RSB6KN",
  },
};
