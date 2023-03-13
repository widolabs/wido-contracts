import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {ethers} from "hardhat";
import CometAbi from "../abi/Comet.json";
import CometExtAbi from "../abi/CometExt.json";
import WethAbi from "../abi/weth.json";
import {Comet, CometExt, Weth} from "../generated";
import {ERC20, MockSwap, WidoFlashLoan, WidoRouter} from "../typechain";
import {expect} from "./setup/chai-setup";
import {ZERO_ADDRESS} from "./utils/addresses";
import * as utils from "./utils/test-utils";

const EULER_FLASH_LOAN_ADDRESS = "0x07df2ad9878F8797B4055230bbAE5C808b8259b3";
const WETH_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
const WBTC_ADDRESS = "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const cUSDCv3_ADDRESS = "0xc3d688B66703497DAA19211EEdff47f25384cdc3";
const cUSDCv3Ext_ADDRESS = "0x285617313887d43256F852cAE0Ee4de4b68D45B0";
const WIDO_ROUTER = "0x7Fb69e8fb1525ceEc03783FFd8a317bafbDfD394";
const WIDO_TOKEN_MANAGER = "0xF2F02200aEd0028fbB9F183420D3fE6dFd2d3EcD";

describe(`WidoRouter`, () => {
  let user1: SignerWithAddress;
  let weth: Weth;
  let wbtc: ERC20;
  let comet: Comet;
  let cometExt: CometExt;
  let widoFlashLoan: WidoFlashLoan;
  let mockSwap: MockSwap;
  let widoRouter: WidoRouter;

  before(async () => {
    [user1] = await ethers.getSigners();
    weth = (await ethers.getContractAt(WethAbi, WETH_ADDRESS)) as Weth;
    wbtc = (await ethers.getContractAt("ERC20", WBTC_ADDRESS)) as ERC20;
    comet = (await ethers.getContractAt(CometAbi, cUSDCv3_ADDRESS)) as Comet;
    cometExt = (await ethers.getContractAt(CometExtAbi, cUSDCv3Ext_ADDRESS)) as CometExt;
    widoRouter = await ethers.getContractAt("WidoRouter", WIDO_ROUTER);
    mockSwap = await ethers.getContractFactory("MockSwap").then((f) => f.deploy(WETH_ADDRESS, WBTC_ADDRESS));
    widoFlashLoan = (await ethers
      .getContractFactory("WidoFlashLoan")
      .then((f) =>
        f.deploy(EULER_FLASH_LOAN_ADDRESS, WIDO_ROUTER, WIDO_TOKEN_MANAGER, comet.address)
      )) as WidoFlashLoan;
  });
  it("Works", async () => {
    // provide eth to user1
    await utils.prepForEth(user1.address);
    // provide wBTC to MockSwap contract for future swaps of weth to wbtc
    await utils.prepForToken(mockSwap.address, wbtc.address, utils.toWei8("10").toString());
    // user wraps eth to weth
    await weth.connect(user1).deposit({value: utils.toWei("2")});

    // user deposit 1 weth collateral
    await weth.connect(user1).approve(comet.address, utils.toWei("1"));
    await comet.connect(user1).supply(WETH_ADDRESS, utils.toWei("1"));
    // user takes loan in usdc
    await comet.connect(user1).withdraw(USDC_ADDRESS, utils.toWei6("1000"));

    // track the initial principal of user
    const principal = await comet.userBasic(user1.address).then((r) => r.principal);

    // user1 gives permission to WidoFlashLoan
    const allowTx = await utils.prepareAllowBySigTx(comet, cometExt, user1, widoFlashLoan.address, true, 0);
    await user1.sendTransaction(allowTx);

    // assume that swap of 1 weth will give 0.08 wbtc
    const flashLoanAmount = utils.toWei8(0.08);
    const swapData = mockSwap.interface.encodeFunctionData("swapWethToWbtc", [
      utils.toWei("1"),
      flashLoanAmount,
      widoRouter.address,
    ]);
    // perform swap of locked weth to wbtc
    await widoFlashLoan
      .connect(user1)
      .swapCollateral(
        WBTC_ADDRESS,
        flashLoanAmount,
        WETH_ADDRESS,
        utils.toWei("1"),
        [{targetAddress: mockSwap.address, data: swapData, fromToken: WETH_ADDRESS, amountIndex: -1}],
        0,
        ZERO_ADDRESS
      );
    // Collateral was supplied from WidoRouter to Compound
    expect(await comet.queryFilter(comet.filters.SupplyCollateral(widoFlashLoan.address, user1.address))).length(1);
    // Collateral was withdrawn from Compound to WidoRouter
    expect(await comet.queryFilter(comet.filters.WithdrawCollateral(user1.address, widoFlashLoan.address))).length(1);

    // user doesn't have WETH as collateral
    expect(await comet.userCollateral(user1.address, WETH_ADDRESS).then((r) => r.balance)).equal(0);
    // but everything what has been taken from flashloan is deposited as collateral
    expect(await comet.userCollateral(user1.address, WBTC_ADDRESS).then((r) => r.balance)).equal(flashLoanAmount);

    // loan is still collateralized
    expect(await comet.isBorrowCollateralized(user1.address)).equal(true);
    // principal of user has not changed
    expect(await comet.userBasic(user1.address).then((r) => r.principal)).equal(principal);
  });
});
