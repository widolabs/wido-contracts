import axios from "axios";
import {HardhatRuntimeEnvironment} from "hardhat/types";
import {task} from "hardhat/config";
import "dotenv/config";
import erc20ABI from "../abi/erc20.json";
// import {WidoRouter} from "../typechain"; TODO: cannot use typechain here ??

task("executeTransaction", "Execute zap transaction")
  .addOptionalParam("from", "From Token Address", "0x0000000000000000000000000000000000000000")
  .addOptionalParam("fromChainId", "From Chain Id", "1")
  .addOptionalParam("to", "To Token Address", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
  .addOptionalParam("toChainId", "To Chain Id", "1")
  .addOptionalParam("amount", "Amount", "1000000000000000000")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const {getNamedAccounts, ethers} = require("hardhat");

    const accounts = await getNamedAccounts();

    const params = new URLSearchParams({
      from_chain_id: taskArgs.fromChainId,
      from_token: taskArgs.from,
      to_chain_id: taskArgs.toChainId,
      to_token: taskArgs.to,
      amount: taskArgs.amount,
      slippage_percentage: "0.02",
      user: accounts["test"],
    });

    const API_URL = process.env.LOCAL ? "http://127.0.0.1:8080" : "https://api.joinwido.com";
    const resp = await axios.get(`${API_URL}/quote_v2?${params}`);
    if (resp.data.status === "not_ok") {
      throw new Error(`Get tx data failed: ${resp.data.err}`);
    }

    const signer = await ethers.getSigner(accounts["test"]);
    const contracts = {
      WidoRouter: <any>await ethers.getContract("WidoRouter"),
    };

    const fromToken = new ethers.Contract(taskArgs.from, erc20ABI, signer);
    await fromToken.approve(contracts.WidoRouter.address, ethers.constants.MaxUint256.toString());

    await signer.sendTransaction({
      to: contracts.WidoRouter.address,
      data: resp.data.data,
      value: resp.data.value,
      gasLimit: 2000000,
    });

    const toToken = new ethers.Contract(taskArgs.to, erc20ABI, signer);
    const balance = await toToken.balanceOf(accounts["test"]);
    console.log(`Final token balance: ${balance}`);
  });
