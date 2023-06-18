import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import WidoRouterArtifact from "../artifacts/contracts/core/WidoRouter.sol/WidoRouter.json";
import {existsSync, readFileSync} from "fs";
import {WRAPPED_NATIVE_MAP} from "../test/core/utils/addresses";
import {ChainName} from "types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const network = (process.env.HARDHAT_FORK != undefined ? process.env.HARDHAT_FORK : hre.network.name) as ChainName;

  const deploymentExists = existsSync(`deployments/${network}/WidoRouter.json`);
  console.log(`Deployment for ${network} exists: ${deploymentExists}`);

  if (deploymentExists) {
    const f = readFileSync(`deployments/${network}/WidoRouter.json`);
    const deployment = JSON.parse(f.toString());
    deployments.save("WidoRouter", {
      address: deployment["address"],
      abi: WidoRouterArtifact.abi,
    });
    return;
  }

  const {deployer} = await getNamedAccounts();
  const wrappedNativeAddress = WRAPPED_NATIVE_MAP[network];

  const bank = "0x5EF7F250f74d4F11A68054AE4e150705474a6D4a";

  console.log(`Using Wrapped Native Address: ${wrappedNativeAddress}`);
  await deploy("WidoRouter", {
    contract: "WidoRouter",
    from: deployer,
    args: [wrappedNativeAddress, bank],
    log: true,
    autoMine: true, // speed up deployment on local network (ganache, hardhat), no effect on live networks
  });
};

export default func;
func.tags = ["WidoRouter"];
