import {expect} from "./chai-setup";
import * as utils from "./test-utils";
import * as routes from "./json-routes";
import {deployments, ethers, getUnnamedAccounts} from "hardhat";
import {setupUsers} from "./utils/users";
import {ERC20, IWidoRouter, WidoRouter} from "../typechain";
import {ZERO_ADDRESS} from "./utils/addresses";
import {beforeAll, describe, it} from "vitest";
const g3CRV = "0xd02a30d33153877bc20e5721ee53dedee0422b2f";
const yv3CRV = "0xF137D22d7B23eeB1950B3e19d1f578c053ed9715";

const setup = deployments.createFixture(async () => {
  await deployments.fixture("WidoRouter");
  const contracts = {
    WidoRouter: <WidoRouter>await ethers.getContract("WidoRouter"),
    USDC: (await ethers.getContract("USDC")) as ERC20,
  };
  const users = await setupUsers(await getUnnamedAccounts(), contracts);
  return {
    ...contracts,
    users,
  };
});

const executeOrderFn =
  "executeOrder((address,address,address,uint256,uint256,uint32,uint32),(address,address,address,bytes,int32)[],uint256,address)";

describe("CurveDepositsV2: fantom", function () {
  if (process.env.HARDHAT_FORK != "fantom") {
    it.skip("skipped due to different network");
    return;
  }
  let acc1: {
    WidoRouter: WidoRouter;
    address: string;
  };

  let usdc: ERC20;
  let widoRouter: WidoRouter;

  beforeAll(async function () {
    const {WidoRouter, USDC, users} = await setup();
    widoRouter = WidoRouter;
    usdc = USDC;
    acc1 = users[0];
  });

  beforeEach(async function () {
    const signer = await ethers.getSigner(acc1.address);
    await utils.resetToken(signer, usdc.address);
    await utils.resetToken(signer, g3CRV);
    await utils.resetToken(signer, yv3CRV);
    await utils.prepForToken(acc1.address, usdc.address, "1000");
  });

  it("should deposit USDC through wido", async function () {
    const signer = await ethers.getSigner(acc1.address);
    await utils.approveForToken(signer, usdc.address, widoRouter.address);

    const swapRoute1 = prepareSwapRoute(routes.curveGeist);
    const swapRoute2 = prepareSwapRoute(routes.yearnUsdc);

    await acc1.WidoRouter.functions[executeOrderFn](
      {
        user: acc1.address,
        fromToken: usdc.address,
        toToken: yv3CRV,
        fromTokenAmount: ethers.utils.parseUnits("100.0", await usdc.decimals()),
        minToTokenAmount: "1",
        nonce: "0",
        expiration: "1753457786",
      },
      [swapRoute1, swapRoute2],
      30,
      ZERO_ADDRESS
    );

    expect(await utils.balanceOf(usdc.address, acc1.address)).to.be.eq("900000000");
    expect(await utils.balanceOf(yv3CRV, acc1.address)).to.not.be.eq("0");
    expect(await utils.balanceOf(usdc.address, widoRouter.address)).to.be.eq("0");
    expect(await utils.balanceOf(g3CRV, widoRouter.address)).to.be.eq("0");
  });
});

const randomAmountMapping: {[key: number]: string} = {
  0: "13276532948576263987562983540912374190287489435798123498723402934789234834383",
  1: "68798126398731264987123649872364932987239472398472398477836473473462734343444",
  2: "23948203948187637712731765478345484734578347543324234452342367745614563456546",
};
const randomAmountEncodedMapping: {[key: number]: string} = {
  0: "1d5a4058ba049c3e870abbc921f6b5f5a3735166bc176866b801887771a93bcf",
  1: "981a5c0ff07f93250fcad7f8cb9c1969c7d2ae2e2832c6e3be83dfc5158acd14",
  2: "34f233fdd349ba5167730e3b6ec27bc4a190639f6007582283b7e1e55fdb3622",
};

function prepareParams(params: any, reservedVariables: any) {
  let stringified = JSON.stringify(params);

  Object.keys(reservedVariables).forEach((varName) => {
    stringified = stringified.replace(varName, reservedVariables[varName]);
  });

  const newParams = JSON.parse(stringified);

  return newParams;
}

/**
 * We assume amount is uint256 and we search for a bytes32
 */
function prepareEditableSwapdata(abi: string, functionName: string, params: any) {
  let amountIndex = -1;
  for (let i = 0; i < 3; i++) {
    const data = new ethers.utils.Interface([abi]).encodeFunctionData(
      functionName,
      prepareParams(params, {$from_token_amount: randomAmountMapping[i]})
    );

    const newIndex = data.indexOf(randomAmountEncodedMapping[i]);

    if (amountIndex === -1) amountIndex = newIndex;
    if (newIndex !== amountIndex) throw new Error("Algorithm to find amount index in swapdata failed");
  }

  const data = new ethers.utils.Interface([abi]).encodeFunctionData(
    functionName,
    prepareParams(params, {$from_token_amount: "1"})
  );

  // we get rid of first 2 chars: 0x
  // bytes32 takes 64chars, so we divide by 2
  return [data, (amountIndex - 2) / 2];
}

function prepareSwapRoute(route: any) {
  const {targetAddress, fromToken, toToken, abi, functionName, params} = route;

  const [data, amountIndex] = prepareEditableSwapdata(abi, functionName, params);

  return {
    targetAddress,
    fromToken,
    toToken,
    data,
    amountIndex,
  } as IWidoRouter.StepStruct;
}
