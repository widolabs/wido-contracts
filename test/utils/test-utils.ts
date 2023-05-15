import {Provider} from "@ethersproject/providers";
import {parseEther} from "@ethersproject/units";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {BigNumber, Signer} from "ethers";
import hre from "hardhat";
import {ethers} from "hardhat";
import erc20ABI from "../../abi/erc20.json";
import {IWidoRouter} from "../../typechain";

const whaleAddress: {[key: string]: string} = {
  // Mainnet
  "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": "0xCFFAd3200574698b78f32232aa9D63eABD290703", // USDC
  "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2": "0x57757E3D981446D585Af0D9Ae4d7DF6D64647806", // WETH
  "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599": "0x6a0C777309ED8f502425AC106c5eac3A6245aaF6", // WBTC
  // Fantom Whale
  "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75": "0x8e1a14761c6637c25097d1724a8c5ec4f6f16e0b", // USDC
  // Polygon Whale
  "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174": "0xF977814e90dA44bFA03b6295A0616a897441aceC", // USDC
  // Optimism Whale
  "0x7F5c764cBc14f9669B88837ca1490cCa17c31607": "0xEbe80f029b1c02862B9E8a70a7e5317C06F62Cae", // USDC
};

async function _getWhaleAddress(tokenAddress: string) {
  return whaleAddress[tokenAddress];
}

export async function getERC20Contract(address: string, signer: Signer | Provider | undefined) {
  return new ethers.Contract(address, erc20ABI, signer);
}

export async function prepForEth(walletAddress: string) {
  const [owner] = await ethers.getSigners();
  await owner.sendTransaction({
    to: walletAddress,
    value: parseEther("10"),
  });
}

export async function prepForToken(walletAddress: string, tokenAddress: string, amount: string) {
  const whaleAddr = await _getWhaleAddress(tokenAddress);
  await prepForEth(whaleAddr);
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [whaleAddr],
  });
  const signer = await ethers.getSigner(whaleAddr);
  const contract = await getERC20Contract(tokenAddress, signer);
  await contract.transfer(walletAddress, amount);
}

export async function balanceOf(tokenAddress: string, walletAddress: string) {
  const signer = await ethers.getSigner(walletAddress);
  const contract = await getERC20Contract(tokenAddress, signer);
  const balance = await contract.balanceOf(signer.address);
  return balance as BigNumber;
}

export async function approveForToken(signer: Signer | Provider | undefined, tokenAddress: string, spender: string) {
  const contract = await getERC20Contract(tokenAddress, signer);
  await contract.approve(spender, ethers.constants.MaxUint256.toString());
}

const domainType = [
  {name: "name", type: "string"},
  {name: "version", type: "string"},
  {name: "chainId", type: "uint256"},
  {name: "verifyingContract", type: "address"},
];

const orderInputType = [
  {name: "tokenAddress", type: "address"},
  {name: "amount", type: "uint256"},
];

const orderOutputType = [
  {name: "tokenAddress", type: "address"},
  {name: "minOutputAmount", type: "uint256"},
];

const orderType = [
  {name: "inputs", type: "OrderInput[]"},
  {name: "outputs", type: "OrderOutput[]"},
  {name: "user", type: "address"},
  {name: "nonce", type: "uint32"},
  {name: "expiration", type: "uint32"},
];

function _parseSignature(signature: string) {
  signature = signature.substring(2);
  const r = signature.substring(0, 64);
  const s = signature.substring(64, 128);
  const v = signature.substring(128, 130);

  return {
    r: "0x" + r,
    s: "0x" + s,
    v: parseInt(v, 16),
  };
}

export async function buildAndSignOrder(
  signer: SignerWithAddress,
  request: IWidoRouter.OrderStruct,
  chainId: number | string,
  widoRouterAddress: string
) {
  const wrDomainData = {
    name: "WidoRouter",
    version: "1",
    chainId: chainId,
    verifyingContract: widoRouterAddress,
  };
  const data = JSON.stringify({
    types: {
      EIP712Domain: domainType,
      OrderInput: orderInputType,
      OrderOutput: orderOutputType,
      Order: orderType,
    },
    domain: wrDomainData,
    primaryType: "Order",
    message: request,
  });

  const params = [signer.address, data];
  const method = "eth_signTypedData_v4";

  const x = await signer._signTypedData(
    wrDomainData,
    {
      Order: orderType,
      OrderInput: orderInputType,
      OrderOutput: orderOutputType,
    },
    request
  );

  // const y = await signer.provider?.send(method, params);

  const signature = _parseSignature(x);
  return {
    order: request,
    v: signature.v,
    r: signature.r,
    s: signature.s,
  };
}

export function toWei(amount: number | string) {
  return ethers.utils.parseUnits(String(amount));
}

export function toWei6(amount: number | string) {
  return ethers.utils.parseUnits(String(amount), 6);
}

export function toWei8(amount: number | string) {
  return ethers.utils.parseUnits(String(amount), 8);
}
