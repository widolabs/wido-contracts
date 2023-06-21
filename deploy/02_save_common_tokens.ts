import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import erc20ABI from "../abi/erc20.json";
import {USDC_MAP} from "../test/core/utils/addresses";
import {ChainName} from "wido";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments} = hre;

  if (!process.env.HARDHAT_FORK) {
    return;
  }

  deployments.save("USDC", {
    address: USDC_MAP[process.env.HARDHAT_FORK as ChainName],
    abi: erc20ABI,
  });
};
export default func;
func.tags = ["USDC"];
