import {expect} from "./setup/chai-setup";
import * as utils from "./utils/test-utils";

import {ethers, deployments, getUnnamedAccounts} from "hardhat";
import {WidoZapUniswapV2Pool} from "../typechain";
import {setupUsers} from "./utils/users";
import {UNI_ROUTER_MAP, USDC_MAP, USDC_WETH_LP_MAP, WETH_MAP} from "./utils/addresses";
import {ChainName} from "wido";
import {beforeAll, describe, it} from "vitest";

const setup = deployments.createFixture(async () => {
  await deployments.fixture(["WidoZapUniswapV2Pool"]);
  const contracts = {
    WidoZapUniswapV2Pool: <WidoZapUniswapV2Pool>await ethers.getContract("WidoZapUniswapV2Pool"),
  };
  const users = await setupUsers(await getUnnamedAccounts(), contracts);
  return {
    ...contracts,
    users,
  };
});

const WETH = WETH_MAP[process.env.HARDHAT_FORK as ChainName];
const USDC = USDC_MAP[process.env.HARDHAT_FORK as ChainName];
const USDC_WETH_LP = USDC_WETH_LP_MAP[process.env.HARDHAT_FORK as ChainName];
const UNI_ROUTER = UNI_ROUTER_MAP[process.env.HARDHAT_FORK as ChainName];

describe(`UniV2Zap`, function () {
  if (!["mainnet", "polygon"].includes(process.env.HARDHAT_FORK as ChainName)) {
    return;
  }
  let user: {address: string} & {WidoZapUniswapV2Pool: WidoZapUniswapV2Pool};
  let widoZapUniswapV2Pool: WidoZapUniswapV2Pool;

  beforeAll(async function () {
    const {WidoZapUniswapV2Pool, users} = await setup();
    widoZapUniswapV2Pool = WidoZapUniswapV2Pool;
    user = users[0];
  });

  it(`should Zap USDC for USDC_WETH_LP`, async function () {
    const fromToken = USDC;
    const toToken = USDC_WETH_LP;

    const signer = await ethers.getSigner(user.address);
    await utils.prepForToken(user.address, fromToken, String(150 * 1e6));
    await utils.approveForToken(signer, fromToken, widoZapUniswapV2Pool.address);
    const initFromTokenBal = await utils.balanceOf(fromToken, user.address);
    const initToTokenBal = await utils.balanceOf(toToken, user.address);

    const amount = "150000000";
    let minToToken = await user.WidoZapUniswapV2Pool.calcMinToAmountForZapIn(
      UNI_ROUTER,
      USDC_WETH_LP,
      fromToken,
      amount
    );
    minToToken = minToToken.mul(998).div(1000);

    await user.WidoZapUniswapV2Pool.zapIn(UNI_ROUTER, USDC_WETH_LP, fromToken, amount, minToToken);

    const finalFromTokenBal = await utils.balanceOf(fromToken, user.address);
    const finalToTokenBal = await utils.balanceOf(toToken, user.address);

    expect(initFromTokenBal.sub(finalFromTokenBal)).to.equal(amount);
    expect(finalToTokenBal.sub(initToTokenBal).toNumber()).to.greaterThanOrEqual(minToToken.toNumber());
  });

  it(`should Zap WETH for USDC_WETH_LP`, async function () {
    const fromToken = WETH;
    const toToken = USDC_WETH_LP;

    const signer = await ethers.getSigner(user.address);
    await utils.prepForToken(user.address, fromToken, String(1 * 1e18));
    await utils.approveForToken(signer, fromToken, widoZapUniswapV2Pool.address);
    const initFromTokenBal = await utils.balanceOf(fromToken, user.address);
    const initToTokenBal = await utils.balanceOf(toToken, user.address);

    const amount = "50000000000000000";
    let minToToken = await user.WidoZapUniswapV2Pool.calcMinToAmountForZapIn(
      UNI_ROUTER,
      USDC_WETH_LP,
      fromToken,
      amount
    );
    minToToken = minToToken.mul(998).div(1000);

    await user.WidoZapUniswapV2Pool.zapIn(UNI_ROUTER, USDC_WETH_LP, fromToken, amount, minToToken);

    const finalFromTokenBal = await utils.balanceOf(fromToken, user.address);
    const finalToTokenBal = await utils.balanceOf(toToken, user.address);

    expect(initFromTokenBal.sub(finalFromTokenBal)).to.equal(amount);
    expect(finalToTokenBal.sub(initToTokenBal).toNumber()).to.greaterThanOrEqual(minToToken.toNumber());
  });

  it(`should Zap USDC_WETH_LP for USDC`, async function () {
    const signer = await ethers.getSigner(user.address);

    await utils.approveForToken(signer, USDC, widoZapUniswapV2Pool.address);
    await utils.approveForToken(signer, USDC_WETH_LP, widoZapUniswapV2Pool.address);

    const initFromTokenBal = await utils.balanceOf(USDC_WETH_LP, user.address);
    const amount = initFromTokenBal.div(3);
    const initToTokenBal = await utils.balanceOf(USDC, user.address);

    let minToToken = await user.WidoZapUniswapV2Pool.calcMinToAmountForZapOut(UNI_ROUTER, USDC_WETH_LP, USDC, amount);
    minToToken = minToToken.mul(998).div(1000);

    await user.WidoZapUniswapV2Pool.zapOut(UNI_ROUTER, USDC_WETH_LP, amount, USDC, minToToken);

    const finalFromTokenBal = await utils.balanceOf(USDC_WETH_LP, user.address);
    const finalToTokenBal = await utils.balanceOf(USDC, user.address);

    expect(finalFromTokenBal).to.equal(initFromTokenBal.sub(amount));
    expect(finalToTokenBal.sub(initToTokenBal).toNumber()).to.greaterThanOrEqual(minToToken.toNumber());
  });

  it(`should Zap USDC_WETH_LP for WETH`, async function () {
    const signer = await ethers.getSigner(user.address);

    await utils.approveForToken(signer, WETH, widoZapUniswapV2Pool.address);
    await utils.approveForToken(signer, USDC_WETH_LP, widoZapUniswapV2Pool.address);

    const initFromTokenBal = await utils.balanceOf(USDC_WETH_LP, user.address);
    const amount = initFromTokenBal.div(2);

    const initToTokenBal = await utils.balanceOf(WETH, user.address);

    let minToToken = await user.WidoZapUniswapV2Pool.calcMinToAmountForZapOut(UNI_ROUTER, USDC_WETH_LP, WETH, amount);
    minToToken = minToToken.mul(998).div(1000);

    await user.WidoZapUniswapV2Pool.zapOut(UNI_ROUTER, USDC_WETH_LP, amount, WETH, minToToken);

    const finalFromTokenBal = await utils.balanceOf(USDC_WETH_LP, user.address);
    const finalToTokenBal = await utils.balanceOf(WETH, user.address);

    expect(finalFromTokenBal).to.equal(initFromTokenBal.sub(amount));
    expect(finalToTokenBal.sub(initToTokenBal).gte(minToToken)).to.be.true;
  });

  it(`should fail Zap WETH for USDC_WETH_LP with high slippage`, async function () {
    const fromToken = WETH;

    const signer = await ethers.getSigner(user.address);
    await utils.prepForToken(user.address, fromToken, String(1 * 1e18));
    await utils.approveForToken(signer, fromToken, widoZapUniswapV2Pool.address);

    const amount = "100000000000000000";
    let minToToken = await user.WidoZapUniswapV2Pool.calcMinToAmountForZapIn(
      UNI_ROUTER,
      USDC_WETH_LP,
      fromToken,
      amount
    );
    minToToken = minToToken.mul(1001).div(1000);

    await expect(
      user.WidoZapUniswapV2Pool.zapIn(UNI_ROUTER, USDC_WETH_LP, fromToken, amount, minToToken)
    ).to.be.revertedWith("Slippage too high");
  });

  it(`should fail Zap USDC_WETH_LP for WETH`, async function () {
    const signer = await ethers.getSigner(user.address);

    await utils.approveForToken(signer, WETH, widoZapUniswapV2Pool.address);
    await utils.approveForToken(signer, USDC_WETH_LP, widoZapUniswapV2Pool.address);

    const initFromTokenBal = await utils.balanceOf(USDC_WETH_LP, user.address);
    const amount = initFromTokenBal;

    let minToToken = await user.WidoZapUniswapV2Pool.calcMinToAmountForZapOut(UNI_ROUTER, USDC_WETH_LP, WETH, amount);
    minToToken = minToToken.mul(1001).div(1000);

    await expect(
      user.WidoZapUniswapV2Pool.zapOut(UNI_ROUTER, USDC_WETH_LP, amount, WETH, minToToken)
    ).to.be.revertedWith("Slippage too high");
  });
});
