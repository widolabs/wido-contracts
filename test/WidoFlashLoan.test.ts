import {expect} from "./setup/chai-setup";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {ethers} from "hardhat";
import CometAbi from "../abi/Comet.json";
import CometExtAbi from "../abi/CometExt.json";
import WethAbi from "../abi/weth.json";
import {Comet, CometExt, Weth} from "../generated";
import {WidoFlashLoan} from "../typechain";
import {ZERO_ADDRESS} from "./utils/addresses";
import * as utils from "./utils/test-utils";

const EULER_FLASH_LOAN_ADDRESS = "0x07df2ad9878F8797B4055230bbAE5C808b8259b3";
const WETH_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
const cUSDCv3_ADDRESS = "0xc3d688B66703497DAA19211EEdff47f25384cdc3";
const cUSDCv3Ext_ADDRESS = "0x285617313887d43256F852cAE0Ee4de4b68D45B0";
const WIDO_ROUTER = "0x7Fb69e8fb1525ceEc03783FFd8a317bafbDfD394";
const WIDO_TOKEN_MANAGER = "0xF2F02200aEd0028fbB9F183420D3fE6dFd2d3EcD";

describe(`WidoRouter`, () => {
  let user1: SignerWithAddress;
  let weth: Weth;
  let comet: Comet;
  let cometExt: CometExt;
  let widoFlashLoan: WidoFlashLoan;

  before(async () => {
    [user1] = await ethers.getSigners();
    await utils.prepForEth(user1.address);
    weth = (await ethers.getContractAt(WethAbi, WETH_ADDRESS)) as Weth;
    comet = (await ethers.getContractAt(CometAbi, cUSDCv3_ADDRESS)) as Comet;
    cometExt = (await ethers.getContractAt(CometExtAbi, cUSDCv3Ext_ADDRESS)) as CometExt;
    widoFlashLoan = (await ethers
      .getContractFactory("WidoFlashLoan")
      .then((f) => f.deploy(EULER_FLASH_LOAN_ADDRESS, WIDO_ROUTER, WIDO_TOKEN_MANAGER))) as WidoFlashLoan;
  });
  it("Works", async () => {
    const flashLoanAmount = utils.toWei(1);
    // in order to call comet.withdrawFrom user1 needs to give WidoRoute manager rights
    const allowBySigSteps = await utils.prepareAllowBySigSteps(comet, cometExt, user1, WIDO_ROUTER);
    await widoFlashLoan.swapCollateral(
      WETH_ADDRESS,
      flashLoanAmount,
      {
        user: widoFlashLoan.address,
        inputs: [
          {
            tokenAddress: weth.address,
            amount: flashLoanAmount,
          },
        ],
        outputs: [],
        nonce: 0,
        expiration: 0,
      },
      [
        allowBySigSteps.allow,
        {
          data: comet.interface.encodeFunctionData("supplyTo", [user1.address, WETH_ADDRESS, flashLoanAmount]),
          fromToken: WETH_ADDRESS,
          amountIndex: -1,
          targetAddress: comet.address,
        },
        {
          data: comet.interface.encodeFunctionData("withdrawFrom", [
            user1.address,
            widoFlashLoan.address,
            WETH_ADDRESS,
            flashLoanAmount,
          ]),
          fromToken: ZERO_ADDRESS,
          amountIndex: -1,
          targetAddress: comet.address,
        },
        allowBySigSteps.disallow,
      ],
      0,
      ZERO_ADDRESS
    );
    // Collateral was supplied from WidoRouter to Compound
    expect(await comet.queryFilter(comet.filters.SupplyCollateral(WIDO_ROUTER, user1.address))).length(1);
    // Collateral was withdrawn from Compound from WidoRouter to WidoFlashLoan
    expect(await comet.queryFilter(comet.filters.WithdrawCollateral(user1.address, widoFlashLoan.address))).length(1);
  });
});
