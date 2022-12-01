import {Web3Address as Address, ChainName} from "wido";

export const ZERO_ADDRESS: Address = "0x0000000000000000000000000000000000000000";

export const USDC_MAP: Record<ChainName, Address> = {
  fantom: "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75",
  mainnet: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  polygon: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
  other: "",
  avalanche: "0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664",
  moonriver: "",
  arbitrum: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
  celo: "",
  goerli: "",
  phuture: "",
  optimism: "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
  binance: "",
};

export const WETH_MAP: Record<ChainName, Address> = {
  mainnet: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  polygon: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
  other: "",
  fantom: "",
  avalanche: "",
  moonriver: "",
  arbitrum: "",
  celo: "",
  goerli: "",
  phuture: "",
  optimism: "0x4200000000000000000000000000000000000006",
  binance: "",
};

export const WRAPPED_NATIVE_MAP: Record<ChainName, Address> = {
  mainnet: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  polygon: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
  other: "",
  fantom: "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83",
  avalanche: "",
  moonriver: "",
  arbitrum: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  celo: "",
  goerli: "",
  phuture: "",
  optimism: "0x4200000000000000000000000000000000000006",
  binance: "",
};

export const USDC_WETH_LP_MAP: Record<ChainName, Address> = {
  mainnet: "0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc",
  polygon: "0x853Ee4b2A13f8a742d64C8F088bE7bA2131f670d",
  other: "",
  fantom: "",
  avalanche: "",
  moonriver: "",
  arbitrum: "",
  celo: "",
  goerli: "",
  phuture: "",
  optimism: "",
  binance: "",
};

export const UNI_ROUTER_MAP: Record<ChainName, Address> = {
  mainnet: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
  polygon: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
  other: "",
  fantom: "",
  avalanche: "",
  moonriver: "",
  arbitrum: "",
  celo: "",
  goerli: "",
  phuture: "",
  optimism: "",
  binance: "",
};
