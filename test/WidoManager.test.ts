import {expect} from "./setup/chai-setup";
import * as utils from "./utils/test-utils";

import {ethers, deployments, getUnnamedAccounts} from "hardhat";
import {ERC20, WidoRouter} from "../typechain";
import {setupUsers} from "./utils/users";
import {USDC_MAP, WETH_MAP, ZERO_ADDRESS} from "./utils/addresses";
import {ChainName} from "wido";
import {IWidoRouter} from "../typechain/contracts/WidoRouter";

const setup = deployments.createFixture(async () => {
  await deployments.fixture(["WidoRouter", "USDC"]);
  const contracts = {
    WidoRouter: <WidoRouter>await ethers.getContract("WidoRouter"),
    USDC: <ERC20>await ethers.getContract("USDC"),
  };
  const users = await setupUsers(await getUnnamedAccounts(), contracts);
  return {
    ...contracts,
    users,
  };
});

const executeOrderFn =
  "executeOrder(((address,uint256)[],(address,uint256)[],address,uint32,uint32),(address,address,bytes,int32)[],uint256,address)";

describe(`WidoManager`, function () {
  if (!["mainnet"].includes(process.env.HARDHAT_FORK as ChainName)) {
    return;
  }
  let alice: {address: string} & {WidoRouter: WidoRouter};
  let bob: {address: string} & {WidoRouter: WidoRouter};

  let widoRouter: WidoRouter;
  let usdcContract: ERC20;
  let widoManagerAddr: string;

  before(async function () {
    const {WidoRouter, users, USDC} = await setup();
    widoRouter = WidoRouter;
    usdcContract = USDC;
    alice = users[0];
    bob = users[1];
    widoManagerAddr = await widoRouter.widoManager();
  });

  it(`should not zap other people's funds`, async function () {
    // arrange
    const WETH = WETH_MAP.mainnet;
    const USDC = USDC_MAP.mainnet;
    const stolenAmount = String(100 * 1e6);

    await utils.prepForToken(alice.address, WETH, "1");
    await utils.approveForToken(await ethers.getSigner(alice.address), WETH, widoManagerAddr);
    await utils.prepForToken(bob.address, USDC, stolenAmount);
    await utils.approveForToken(await ethers.getSigner(bob.address), USDC, widoManagerAddr);
    // act
    const steps: IWidoRouter.StepStruct[] = [
      {
        fromToken: WETH,
        targetAddress: usdcContract.address,
        data: usdcContract.interface.encodeFunctionData("transferFrom", [
          bob.address,
          widoRouter.address,
          stolenAmount,
        ]),
        amountIndex: -1,
      },
    ];
    const promise = alice.WidoRouter.functions[executeOrderFn](
      {
        user: alice.address,
        inputs: [
          {
            tokenAddress: WETH,
            amount: "1",
          },
        ],
        outputs: [
          {
            tokenAddress: USDC,
            minOutputAmount: stolenAmount,
          },
        ],
        nonce: "0",
        expiration: "0",
      },
      steps,
      30,
      ZERO_ADDRESS
    );
    // assert
    await expect(promise).to.be.revertedWith("ERC20: transfer amount exceeds allowance");
  });
});
