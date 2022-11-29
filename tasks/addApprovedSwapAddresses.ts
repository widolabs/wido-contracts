import axios from "axios";
import {HardhatRuntimeEnvironment} from "hardhat/types";
import {task} from "hardhat/config";
import "dotenv/config";

const chainIds: {[key: string]: number} = {
  mainnet: 1,
  fantom: 250,
  arbitrum: 42161,
  polygon: 137,
};

task("addApprovedSwapAddresses", "Add approved swap addresses to the contract").setAction(
  async (taskArgs: unknown, hre: HardhatRuntimeEnvironment) => {
    const testing = ["hardhat", "localhost"].includes(hre.network.name);
    let chainId: number;
    if (testing) {
      // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
      chainId = chainIds[process.env.HARDHAT_FORK!];
    } else {
      chainId = chainIds[hre.network.name];
    }

    const widoRouter = await hre.ethers.getContract("WidoAddressRegistry");
    const swapAddresses = (await axios.get(`https://api.joinwido.com/routes/verified-swap-address/${chainId}`)).data[
      "addresses"
    ];
    for (const sr of swapAddresses) {
      if ((await widoRouter.approvedSwapAddresses(sr)) == false) {
        console.log(`Adding address: ${sr}`);
        await widoRouter.addApprovedSwapAddress(sr);
      }
    }
  }
);
