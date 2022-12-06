import {expect} from "./setup/chai-setup";
import {WidoRouter, Token1, Token2, MockVault, IWidoRouter} from "../typechain";
import {ethers, deployments, getUnnamedAccounts} from "hardhat";
import {setupUsers} from "./utils/users";
import {beforeAll, describe, it} from "vitest";
import {ZERO_ADDRESS} from "./utils/addresses";

const setup = deployments.createFixture(async () => {
  await deployments.fixture(["WidoRouter", "TestTokens"]);
  const contracts = {
    WidoRouter: <WidoRouter>await ethers.getContract("WidoRouter"),
    Token1: <Token1>await ethers.getContract("Token1"),
    Token2: <Token2>await ethers.getContract("Token2"),
    MockVault: <MockVault>await ethers.getContract("MockVault"),
  };
  const users = await setupUsers(await getUnnamedAccounts(), contracts);
  return {
    ...contracts,
    users,
  };
});

const executeOrderFn =
  "executeOrder((address,address,address,uint256,uint256,uint32,uint32),(address,address,address,bytes,int32)[],uint256,address)";

describe(`WidoRouterUnit`, function () {
  let user: {address: string} & {WidoRouter: WidoRouter; Token1: Token1; Token2: Token2; MockVault: MockVault};
  let widoRouter: WidoRouter;
  let token1: Token1;
  let vault: MockVault;

  beforeAll(async function () {
    const {WidoRouter, Token1, MockVault, users} = await setup();
    widoRouter = WidoRouter;
    token1 = Token1;
    vault = MockVault;

    user = users[0];

    user.Token1.mint(user.address, ethers.utils.parseUnits("100", 18));
  });

  it(`should Zap Token1 for VLT`, async function () {
    const fromToken = token1.address;
    const toToken = vault.address;

    await user.Token1.approve(widoRouter.address, ethers.constants.MaxUint256.toString());

    const initFromTokenBal = await user.Token1.balanceOf(user.address);
    const initToTokenBal = await user.MockVault.balanceOf(user.address);

    const amount = ethers.utils.parseUnits("1", 18);
    const data = vault.interface.encodeFunctionData("deposit", [amount]);

    const swapRoute: IWidoRouter.StepStruct[] = [
      {fromToken, toToken, targetAddress: vault.address, data, amountIndex: 4},
    ];

    await user.WidoRouter.functions[executeOrderFn](
      {
        user: user.address,
        fromToken: fromToken,
        toToken: toToken,
        fromTokenAmount: amount,
        minToTokenAmount: "1",
        nonce: "0",
        expiration: "0",
      },
      swapRoute,
      30,
      ZERO_ADDRESS
    );

    const finalFromTokenBal = await user.Token1.balanceOf(user.address);
    const finalToTokenBal = await user.MockVault.balanceOf(user.address);

    expect(initFromTokenBal.sub(finalFromTokenBal)).to.equal(amount);
    expect(finalToTokenBal.sub(initToTokenBal)).to.equal("997000000000000000");
  });
});
