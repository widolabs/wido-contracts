import {Provider} from "@ethersproject/providers";
import {parseEther} from "@ethersproject/units";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {BigNumber, Signer} from "ethers";
import hre from "hardhat";
import {ethers} from "hardhat";
import erc20ABI from "../../abi/erc20.json";
import {IWidoRouter} from "../../typechain";
import {Comet, CometExt} from "../../generated";
import {ZERO_ADDRESS} from "./addresses";

const whaleAddress: {[key: string]: string} = {
  // Mainnet
  "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": "0xCFFAd3200574698b78f32232aa9D63eABD290703", // USDC
  "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2": "0x06920c9fc643de77b99cb7670a944ad31eaaa260", // WETH
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
  owner.sendTransaction({
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

export async function prepareAllowBySigSignature(
  comet: Comet,
  cometExt: CometExt,
  signer: SignerWithAddress,
  manager: string,
  isAllowed: boolean,
  nonce: number | BigNumber
) {
  const domain = {
    name: await cometExt.name(),
    version: await cometExt.version(),
    chainId: await ethers.provider.getNetwork().then((n) => n.chainId),
    verifyingContract: comet.address,
  };
  const data = {
    owner: signer.address,
    manager,
    isAllowed,
    nonce,
    // set to 15 minutes
    expiry: await currentTimestamp().then((t) => t + 15 * 60),
  };
  const signature = await signer._signTypedData(
    domain,
    {
      Authorization: [
        {name: "owner", type: "address"},
        {name: "manager", type: "address"},
        {name: "isAllowed", type: "bool"},
        {name: "nonce", type: "uint256"},
        {name: "expiry", type: "uint256"},
      ],
    },
    data
  );
  return {..._parseSignature(signature), expiry: data.expiry};
}

export async function prepareAllowBySigTx(
  comet: Comet,
  cometExt: CometExt,
  owner: SignerWithAddress,
  managerAddress: string,
  isAllowed: boolean,
  nonce: number | BigNumber
) {
  const {r, v, s, expiry} = await prepareAllowBySigSignature(comet, cometExt, owner, managerAddress, isAllowed, nonce);
  const tx = await cometExt.populateTransaction.allowBySig(
    owner.address,
    managerAddress,
    isAllowed,
    nonce,
    expiry,
    v,
    r,
    s
  );
  tx.to = comet.address;
  return tx;
}

export async function prepareAllowBySigSteps(
  comet: Comet,
  cometExt: CometExt,
  owner: SignerWithAddress,
  managerAddress: string
) {
  const nonce = await comet.userNonce(owner.address);
  const txAllow = await prepareAllowBySigTx(comet, cometExt, owner, managerAddress, true, nonce);
  const txDisallow = await prepareAllowBySigTx(comet, cometExt, owner, managerAddress, false, nonce.add(1));
  return {
    allow: {fromToken: ZERO_ADDRESS, targetAddress: txAllow.to!, data: txAllow.data!, amountIndex: -1},
    disallow: {fromToken: ZERO_ADDRESS, targetAddress: txDisallow.to!, data: txDisallow.data!, amountIndex: -1},
  };
}

export async function currentTimestamp() {
  const blockNumber = ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);
  return block.timestamp;
}

export function toWei(amount: number | string) {
  return ethers.utils.parseUnits(String(amount));
}

export function toWei6(amount: number | string) {
  return ethers.utils.parseUnits(String(amount), 6);
}
