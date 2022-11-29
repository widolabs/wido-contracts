export const curveGeist = {
  targetAddress: "0x0fa949783947Bf6c1b171DB13AEACBB488845B3f",
  fromToken: "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75", // USDC
  toToken: "0xd02a30d33153877bc20e5721ee53dedee0422b2f", // g3CRV
  abi: "function add_liquidity(uint256[3],uint256,bool)",
  functionName: "add_liquidity",
  params: [
    [
      0, // dai
      "$from_token_amount", // usdc
      0, // usdt
    ],
    "1", // min to receive
    true, // use_underlying
  ],
};

export const yearnUsdc = {
  targetAddress: "0xF137D22d7B23eeB1950B3e19d1f578c053ed9715",
  fromToken: "0xd02a30d33153877bc20e5721ee53dedee0422b2f", // g3CRV
  toToken: "0xF137D22d7B23eeB1950B3e19d1f578c053ed9715", // yv3CRV
  abi: "function deposit(uint256)",
  functionName: "deposit",
  params: [
    "$from_token_amount", // usdc
  ],
};
