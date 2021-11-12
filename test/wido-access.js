const { expect } = require("chai");
const { ethers } = require("hardhat");
const hardhatConfig = require("../hardhat.config");
const utils = require("./test-utils");


describe("Wido", function () {
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

        [owner, addr1, addr2] = await ethers.getSigners();
        const Wido = await ethers.getContractFactory("Wido");
        wido = await Wido.deploy();
        await wido.deployed();
        await wido.initialize(1);
    });

    it("Should have owner in approved transactor", async function () {
        expect(await wido.approvedTransactors(owner.address)).to.true;
    });

    it("Should not have addr1 and addr2 in approved transactions", async function () {
        expect(await wido.approvedTransactors(addr1.address)).to.false;
        expect(await wido.approvedTransactors(addr2.address)).to.false;
    });

    it("Should not be accessible to others outside approved transactors", async function () {
        expect(wido.connect(addr1).depositPool([], ethers.constants.AddressZero, "0x00")).to.be.revertedWith("Not an approved transactor");
        expect(wido.connect(addr2).depositPool([], "0x92be6adb6a12da0ca607f9d87db2f9978cd6ec3e", "0x00")).to.be.revertedWith("Not an approved transactor");
    });

    it("Should be accessible to approved transactors", async function () {
        await wido.addApprovedTransactor(addr1.address);
        expect(wido.connect(addr1).depositPool([], ethers.constants.AddressZero, "0x00")).to.be.revertedWith("DepositTx length should be greater than 0");
    });

    it("Should remove approved transactors", async function () {
        await wido.removeApprovedTransactor(owner.address);
        expect(wido.depositPool([], ethers.constants.AddressZero, "0x00")).to.be.revertedWith("Not an approved transactor");
    });
});