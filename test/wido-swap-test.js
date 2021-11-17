const { expect } = require("chai");
const { ethers } = require("hardhat");
const hardhatConfig = require("../hardhat.config");
const utils = require("./test-utils");

describe("WidoSwap", function () {
    var wido;
    this.timeout(500000);

    beforeEach(async function () {
        await network.provider.request({
            method: "hardhat_reset",
            params: [
                {
                    forking: {
                        jsonRpcUrl: hardhatConfig.networks.hardhat.forking.url,
                        blockNumber: 13588340
                    },
                },
            ],
        });

        const WidoSwap = await ethers.getContractFactory("WidoSwap");
        wido = await WidoSwap.deploy();
        await wido.deployed();
        await wido.initialize(1);
    });

    it("Should swap from yUSDC to yUSDC for two txns", async function () {
        const [owner, acc1, acc2] = await ethers.getSigners();
        const fromVaultAddress = "0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9";
        const toVaultAddress = "0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE";

        await Promise.all([utils.prepForToken(acc1.address, fromVaultAddress, "1000"), utils.prepForToken(acc2.address, fromVaultAddress, "10000")]);
        await Promise.all([utils.approveWidoForVault(acc1, fromVaultAddress, wido.address), utils.approveWidoForVault(acc2, fromVaultAddress, wido.address)]);

        const swap = await Promise.all([utils.buildAndSignSwapRequest(acc1, {
            user: acc1.address,
            from_vault: fromVaultAddress,
            amount: ethers.utils.parseUnits('1000', 6).toString(),
            to_vault: toVaultAddress,
            nonce: 0,
            expiration: 1732307386,
        }),
        utils.buildAndSignSwapRequest(acc2, {
            user: acc2.address,
            from_vault: fromVaultAddress,
            amount: ethers.utils.parseUnits('4300', 6).toString(),
            to_vault: toVaultAddress,
            nonce: 0,
            expiration: 1732307386,
        })]);

        const contract = await utils.getERC20Contract(toVaultAddress, owner);

        expect(await contract.balanceOf(acc1.address)).to.equal(0);
        expect(await contract.balanceOf(acc2.address)).to.equal(0);
        await wido.swapBatch(swap, "0xF12eeAB1C759dD7D8C012CcA6d8715EEd80e51b6", 0, []);
        expect(await contract.balanceOf(acc1.address)).to.equal("1062195308");
        expect(await contract.balanceOf(acc2.address)).to.equal("4567439825");
        expect(await contract.balanceOf(wido.address)).to.equal("118776508");
    });
});
