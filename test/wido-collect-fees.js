const { expect } = require("chai");
const { ethers } = require("hardhat");
const hardhatConfig = require("../hardhat.config");
const utils = require("./test-utils");


describe("WidoCollectFees", function () {
  this.timeout(50000);
  var wido;
  var owner;
  var addr1;
  var addr2;

  beforeEach(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: hardhatConfig.networks.hardhat.forking.url,
            blockNumber: hardhatConfig.networks.hardhat.forking.blockNumber,
          },
        },
      ],
    });

    [owner, addr1, addr2] = await ethers.getSigners()
    const Wido = await ethers.getContractFactory("Wido");
    wido = await Wido.deploy();
    await wido.deployed();
    await wido.initialize(1);
  });

  it("Should fail withdrawToken for non owner", async function () {
    expect(wido.connect(addr1).withdrawToken("0x6b175474e89094c44da98b954eedeac495271d0f", 100)).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should fail withdrawTokenTo for non owner", async function () {
    expect(wido.connect(addr1).withdrawTokenTo("0x6b175474e89094c44da98b954eedeac495271d0f", addr2.address, 100)).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should successfully withdrawToken to owner", async function () {
    const [owner, acc1, acc2] = await ethers.getSigners();

    await Promise.all([utils.prepForUSDC(acc1.address, "2000"), utils.prepForUSDC(acc2.address, "2000")]);
    await Promise.all([utils.approveWidoForUSDC(acc1, wido.address), utils.approveWidoForUSDC(acc2, wido.address)]);

    const deposit = await Promise.all([utils.buildAndSignDepositRequest(acc1, {
      user: acc1.address,
      token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      vault: "0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e",
      amount: ethers.utils.parseUnits('100', 6).toString(),
      nonce: 0,
      expiration: 1682307386,
    }),
    utils.buildAndSignDepositRequest(acc2, {
      user: acc2.address,
      token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      vault: "0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e",
      amount: ethers.utils.parseUnits('123', 6).toString(),
      nonce: 0,
      expiration: 1682307386,
    })]);

    const yUSDCContract = await hre.ethers.getVerifiedContractAt("0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e");

    await wido.depositPool(deposit, ethers.constants.AddressZero, "0x00");
    const bal = await yUSDCContract.balanceOf(wido.address);
    expect(bal).to.equal(60341802);
    await wido.connect(owner).withdrawToken("0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e", bal);
    expect(await yUSDCContract.balanceOf(wido.address)).to.equal(0);
    expect(await yUSDCContract.balanceOf(owner.address)).to.equal(bal);
  });

  it("Should successfully withdrawTokenTo to address", async function () {
    const [owner, acc1, acc2] = await ethers.getSigners();

    await Promise.all([utils.prepForUSDC(acc1.address, "2000"), utils.prepForUSDC(acc2.address, "2000")]);
    await Promise.all([utils.approveWidoForUSDC(acc1, wido.address), utils.approveWidoForUSDC(acc2, wido.address)]);

    const deposit = await Promise.all([utils.buildAndSignDepositRequest(acc1, {
      user: acc1.address,
      token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      vault: "0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e",
      amount: ethers.utils.parseUnits('100', 6).toString(),
      nonce: 0,
      expiration: 1682307386,
    }),
    utils.buildAndSignDepositRequest(acc2, {
      user: acc2.address,
      token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      vault: "0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e",
      amount: ethers.utils.parseUnits('123', 6).toString(),
      nonce: 0,
      expiration: 1682307386,
    })]);

    const yUSDCContract = await hre.ethers.getVerifiedContractAt("0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e");

    await wido.depositPool(deposit, ethers.constants.AddressZero, "0x00");
    const bal = await yUSDCContract.balanceOf(wido.address);
    expect(bal).to.equal(60341802);
    const addr2Bal = await yUSDCContract.balanceOf(addr2.address);
    await wido.connect(owner).withdrawTokenTo("0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e", addr2.address, bal);
    expect(await yUSDCContract.balanceOf(wido.address)).to.equal(0);
    expect(await yUSDCContract.balanceOf(addr2.address)).to.equal(addr2Bal.add(bal));
  });
});
