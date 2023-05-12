import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import hre, { ethers } from "hardhat";
import CometAbi from "../abi/Comet.json";
import CometExtAbi from "../abi/CometExt.json";
import { Comet, CometExt } from "../generated";
import { ERC20, MockSwap, WidoFlashLoan, WidoRouter } from "../typechain";
import { expect } from "./setup/chai-setup";
import { ZERO_ADDRESS } from "./utils/addresses";
import * as utils from "./utils/test-utils";
import { BigNumber } from 'ethers';

const FLASH_LOAN_PROVIDER = "0x4EAF187ad4cE325bF6C84070b51c2f7224A51321";
const WETH_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
const WBTC_ADDRESS = "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const cUSDCv3_ADDRESS = "0xc3d688B66703497DAA19211EEdff47f25384cdc3";
const cUSDCv3Ext_ADDRESS = "0x285617313887d43256F852cAE0Ee4de4b68D45B0";
const WIDO_ROUTER = "0x7Fb69e8fb1525ceEc03783FFd8a317bafbDfD394";
const WIDO_TOKEN_MANAGER = "0xF2F02200aEd0028fbB9F183420D3fE6dFd2d3EcD";

const setup = async (blockNumber: number) => {
  // Use Mainnet fork
  await hre.network.provider.request({
    method: 'hardhat_reset',
    params: [
      {
        forking: {
          jsonRpcUrl: process.env.ETH_NODE_URI_MAINNET,
          blockNumber: blockNumber,
        },
      },
    ],
  })
}

describe(`WidoRouter`, () => {
  let user1: SignerWithAddress;
  let comet: Comet;
  let cometExt: CometExt;
  let widoFlashLoan: WidoFlashLoan;
  let mockSwap: MockSwap;
  let widoRouter: WidoRouter;

  const initialCollateral = WBTC_ADDRESS;
  const initialCollateralAmount = utils.toWei8(0.06);
  const finalCollateral = WETH_ADDRESS;
  const finalCollateralAmount = utils.toWei("1");

  before(async () => {
    //await setup(16768675);
    [user1] = await ethers.getSigners();
    comet = (await ethers.getContractAt(CometAbi, cUSDCv3_ADDRESS)) as Comet;
    cometExt = (await ethers.getContractAt(CometExtAbi, cUSDCv3Ext_ADDRESS)) as CometExt;
    widoRouter = await ethers.getContractAt("WidoRouter", WIDO_ROUTER);
    mockSwap = await ethers.getContractFactory("MockSwap").then((f) =>
      f.deploy(WETH_ADDRESS, WBTC_ADDRESS)
    );
    widoFlashLoan = (await ethers
      .getContractFactory("WidoFlashLoan")
      .then((f) =>
        f.deploy(FLASH_LOAN_PROVIDER, WIDO_ROUTER, WIDO_TOKEN_MANAGER, comet.address)
      )) as WidoFlashLoan;
  });

  it("Works", async () => {
    /** Arrange */
    // provide final collateral to MockSwap contract for future swap
    await utils.prepForToken(
      mockSwap.address,
      finalCollateral,
      finalCollateralAmount.toString()
    );

    // provide initial collateral to user
    await utils.prepForToken(
      user1.address,
      initialCollateral,
      initialCollateralAmount.toString()
    );

    // deposit initial collateral
    await depositIntoCompound(initialCollateral, initialCollateralAmount);

    // take loan in USDC
    await comet
      .connect(user1)
      .withdraw(USDC_ADDRESS, utils.toWei6("1000"));

    // track the initial principal
    const initialPrincipal = await userPrincipal(user1.address);

    // give permission to WidoFlashLoan
    const tx = await cometExt
      .connect(user1)
      .populateTransaction.allow(widoFlashLoan.address, true);
    tx.to = comet.address;
    await user1.sendTransaction(tx);

    // prepare calldata for WidoRouter step
    const swapData = mockSwap.interface.encodeFunctionData("swapWbtcToWeth", [
      initialCollateralAmount,
      finalCollateralAmount,
      widoRouter.address,
    ]);

    /** Act */
    await widoFlashLoan
      .connect(user1)
      .swapCollateral(
        finalCollateral,
        finalCollateralAmount,
        initialCollateral,
        initialCollateralAmount,
        [{
          targetAddress: mockSwap.address,
          data: swapData,
          fromToken: initialCollateral,
          amountIndex: -1
        }],
        0,
        ZERO_ADDRESS
      );

    /** Assert */
    // Collateral was supplied from WidoRouter to Compound
    expect(
      await comet.queryFilter(comet.filters.SupplyCollateral(widoFlashLoan.address, user1.address))
    ).length(1);

    // Collateral was withdrawn from Compound to WidoRouter
    expect(
      await comet.queryFilter(comet.filters.WithdrawCollateral(user1.address, widoFlashLoan.address))
    ).length(1);

    // user doesn't have initial collateral
    expect(await userCollateral(initialCollateral)).equal(0);

    // user has final collateral deposited
    expect(await userCollateral(finalCollateral)).equal(finalCollateralAmount);

    // loan is still collateralized
    expect(await comet.isBorrowCollateralized(user1.address)).equal(true);

    // principal of user has not changed
    const finalPrincipal = await userPrincipal(user1.address);
    expect(finalPrincipal).equal(initialPrincipal);
  });

  async function depositIntoCompound(asset: string, amount: BigNumber) {
    const contract = await ethers.getContractAt("ERC20", asset);
    await contract.connect(user1).approve(comet.address, amount);
    await comet.connect(user1).supply(asset, amount);
  }

  async function userPrincipal(address: string) {
    return await comet.userBasic(address).then((r) => r.principal);
  }

  async function userCollateral(address: string) {
    return await comet.userCollateral(user1.address, address).then((r) => r.balance);
  }

});
