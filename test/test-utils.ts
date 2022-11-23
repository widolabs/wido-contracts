import {Provider} from "@ethersproject/providers";
import {parseEther} from "@ethersproject/units";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {BigNumber, Signer} from "ethers";
import {BigNumberish} from "ethers";
import hre from "hardhat";
import {ethers} from "hardhat";
import erc20ABI from "../abi/erc20.json";
import {IWidoRouter} from "../typechain";

const usdcWhaleAddr = "0xCFFAd3200574698b78f32232aa9D63eABD290703";

const whaleAddress: {[key: string]: string} = {
  "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": usdcWhaleAddr,
  "0xdCD90C7f6324cfa40d7169ef80b12031770B4325": "0x7ccc9481fbca38091044194982575f305d3e9e22", // crvStEth
  "0xd9788f3931Ede4D5018184E198699dC6d66C1915": "0xE4D3DF079FBEF6529c893Ee4E9298711d480fF35", // AAVE yVault
  "0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9": "0x44508487Ca6A0e84944dd171243FfD18fC760525", // yUSDC 0x5f1
  "0xE14d13d8B3b85aF791b2AADD661cDBd5E6097Db1": "0x4F76fF660dc5e37b098De28E6ec32978E4b5bEb6", // YFI 0.3.2
  "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2": "0x06920c9fc643de77b99cb7670a944ad31eaaa260", // WETH
  "0x6B175474E89094C44Da98b954EedeAC495271d0F": "0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8", // DAI
  // FanTOM Whale
  "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75": "0x8e1a14761c6637c25097d1724a8c5ec4f6f16e0b",
  "0xe578c856933d8e1082740bf7661e379aa2a30b26": "0xd1a992417a0abffa632cbde4da9f5dcf85caa858",
  "0xEF0210eB96c7EB36AF8ed1c20306462764935607": "0xDeE01F517E0B152E878c7940DF07F1Dd966b8fCC",
  "0x1b48641D8251c3E84ecbe3f2bD76B3701401906D": "0x69258d1ed30A0e5971992921cb5787b9c7a2909D", // yvDOLA
  // Avalanche Whale
  "0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664": "0xA465900f5eb9aACdBAC1b956Fd7045D02b4370d4", // USDC.e
  "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E": "0x279f8940ca2a44C35ca3eDf7d28945254d0F0aE6", // USDC
  // Polygon Whale
  "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174": "0xF977814e90dA44bFA03b6295A0616a897441aceC",
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

export async function resetToken(signer: SignerWithAddress, tokenAddress: string) {
  const contract = await getERC20Contract(tokenAddress, signer);
  const balance = (await contract.balanceOf(signer.address)).toString();
  if (balance !== "0") {
    await contract.transfer("0x0000000000000000000000000000000000000001", balance);
  }
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

const orderType = [
  {name: "user", type: "address"},
  {name: "fromToken", type: "address"},
  {name: "toToken", type: "address"},
  {name: "fromTokenAmount", type: "uint256"},
  {name: "minToTokenAmount", type: "uint256"},
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
    },
    request
  );

  // @ts-expect-error send exists
  const y = await signer.provider?.send(method, params);

  const signature = _parseSignature(x);
  return {
    order: request,
    v: signature.v,
    r: signature.r,
    s: signature.s,
  };
}

export async function formatBalance(token: string, wallet: string, decimals: BigNumberish) {
  const balance = await balanceOf(token, wallet);
  return ethers.utils.formatUnits(balance, decimals);
}
