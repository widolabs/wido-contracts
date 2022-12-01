import "dotenv/config";
import "@tenderly/hardhat-tenderly";
import "hardhat-contract-sizer";
import "@openzeppelin/hardhat-upgrades";
import {HardhatUserConfig} from "hardhat/types";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-gas-reporter";
import "@typechain/hardhat";
import "solidity-coverage";
import "hardhat-deploy-tenderly";
import "hardhat-preprocessor";
import "hardhat-docgen";
import {removeConsoleLog} from "hardhat-preprocessor";
import {node_url, accounts, addForkConfiguration} from "./utils/network";
import "hardhat-log-remover";

import {ChainName, getChainId} from "wido";

const chainId = process.env.HARDHAT_FORK ? getChainId(process.env.HARDHAT_FORK as ChainName) : undefined;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 2000,
      },
    },
  },
  namedAccounts: {
    deployer: 0,
    test: 4,
  },
  networks: addForkConfiguration({
    hardhat: {
      chainId: chainId,
      initialBaseFeePerGas: 0, // to fix : https://github.com/sc-forks/solidity-coverage/issues/652, see https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136
    },
    localhost: {
      url: node_url("localhost"),
      accounts: accounts(),
    },
    staging: {
      url: node_url("rinkeby"),
      accounts: accounts("rinkeby"),
    },
    production: {
      url: node_url("mainnet"),
      accounts: accounts("mainnet"),
    },
    mainnet: {
      url: node_url("mainnet"),
      accounts: accounts("mainnet"),
    },
    rinkeby: {
      url: node_url("rinkeby"),
      accounts: accounts("rinkeby"),
    },
    kovan: {
      url: node_url("kovan"),
      accounts: accounts("kovan"),
    },
    goerli: {
      url: node_url("goerli"),
      accounts: accounts("goerli"),
    },
    fantom: {
      url: node_url("fantom"),
      accounts: accounts("fantom"),
    },
    arbitrum: {
      url: node_url("arbitrum"),
      accounts: accounts("arbitrum"),
    },
    polygon: {
      url: node_url("polygon"),
      accounts: accounts("polygon"),
    },
    avalanche: {
      url: node_url("avalanche"),
      accounts: accounts("avalanche"),
    },
    optimism: {
      url: node_url("optimism"),
      accounts: accounts("optimism"),
    },
  }),
  paths: {
    sources: "contracts",
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 100,
    enabled: process.env.REPORT_GAS ? true : false,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    maxMethodDiff: 10,
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
  external: process.env.HARDHAT_FORK
    ? {
        deployments: {
          // process.env.HARDHAT_FORK will specify the network that the fork is made from.
          // these lines allow it to fetch the deployments from the network being forked from both for node and deploy task
          hardhat: ["deployments/" + process.env.HARDHAT_FORK],
          localhost: ["deployments/" + process.env.HARDHAT_FORK],
        },
      }
    : undefined,
  etherscan: {
    // Your API key for Etherscan
    apiKey: {
      mainnet: "",
      opera: "",
      avalanche: "", // snowtrace.io
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  tenderly: {
    username: process.env.TENDERLY_USERNAME as string,
    project: "project",
  },
  preprocess: {
    eachLine: removeConsoleLog((hre) => hre.network.name !== "hardhat" && hre.network.name !== "localhost"),
  },
  docgen: process.env.SKIP_DOCGEN
    ? {}
    : {
        clear: true,
        runOnCompile: true,
      },
};

export default config;
