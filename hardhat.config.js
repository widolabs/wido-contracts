require("@nomiclabs/hardhat-waffle");
require('hardhat-contract-sizer');
require("hardhat-etherscan-abi");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 1,
      forking: {
        url: process.env.MAINNET_ARCHIVE_NODE_URL,
        blockNumber: 13524281
      },
    },
    ropsten: {
      url: process.env.ROPSTEN_NODE_URL,
      accounts: [process.env.ROPSTEN_PKEY],
      gasMultiplier: 2,
      // gasPrice: 10000000000
    },
    goerli: {
      url: process.env.GOERLI_NODE_URL,
      accounts: [process.env.GOERLI_PKEY],
    },
    mainnet: {
      url: process.env.MAINNET_NODE_URL,
      accounts: [process.env.MAINNET_PKEY],
      gasPrice: 100 * 1000000000,
      gasMultiplier: 1.2,
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  }
};
