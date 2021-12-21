const { expect } = require("chai");
const { ethers } = require("hardhat");
const hardhatConfig = require("../hardhat.config");
const utils = require("./test-utils");


describe("WidoWithdraw", function () {
    var wido;
    this.timeout(500000);

    beforeEach(async function () {
        await network.provider.request({
            method: "hardhat_reset",
            params: [
                {
                    forking: {
                        jsonRpcUrl: hardhatConfig.networks.hardhat.forking.url,
                        // blockNumber: hardhatConfig.networks.hardhat.forking.blockNumber,
                        blockNumber: 13588340
                    },
                },
            ],
        });

        const WidoWithdraw = await ethers.getContractFactory("WidoWithdraw");
        wido = await WidoWithdraw.deploy();
        await wido.deployed();
        await wido.initialize(1);
        await wido.addPriceOracle("0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9", "0x6Df09E975c830ECae5bd4eD9d90f3A95a4f88012")  // AAVE
    });

    it("Should withdraw from vault for two txns", async function () {
        const [owner, acc1, acc2] = await ethers.getSigners();
        const vaultAddress = "0xd9788f3931Ede4D5018184E198699dC6d66C1915";
        const underlyingTokenAddress = "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9";

        await Promise.all([utils.prepForToken(acc1.address, vaultAddress, "1000"), utils.prepForToken(acc2.address, vaultAddress, "1000")]);
        await Promise.all([utils.approveWidoForVault(acc1, vaultAddress, wido.address), utils.approveWidoForVault(acc2, vaultAddress, wido.address)]);

        const withdraw = await Promise.all([utils.buildAndSignWithdrawRequest(acc1, {
            user: acc1.address,
            vault: vaultAddress,
            amount: ethers.utils.parseUnits('1000', 18).toString(),
            token: underlyingTokenAddress,
            nonce: 0,
            expiration: 1732307386,
        }),
        utils.buildAndSignWithdrawRequest(acc2, {
            user: acc2.address,
            vault: vaultAddress,
            amount: ethers.utils.parseUnits('1000', 18).toString(),
            token: underlyingTokenAddress,
            nonce: 0,
            expiration: 1732307386,
        })]);

        const underlyingContract = await utils.getERC20Contract(underlyingTokenAddress, owner);

        expect(await underlyingContract.balanceOf(acc1.address)).to.equal(0);
        expect(await underlyingContract.balanceOf(acc2.address)).to.equal(0);
        await wido.withdrawBatch(withdraw, ethers.constants.AddressZero, "0x00");
        expect(await underlyingContract.balanceOf(acc1.address)).to.equal("1010477315058394512293");
        expect(await underlyingContract.balanceOf(acc2.address)).to.equal("1010477315058394512293");
        expect(await underlyingContract.balanceOf(wido.address)).to.equal("579849033732355009");
    });


    it("Should withdraw from vault for two txns", async function () {
        const [owner, acc1, acc2] = await ethers.getSigners();
        const vaultAddress = "0xd9788f3931Ede4D5018184E198699dC6d66C1915";
        const underlyingTokenAddress = "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9";

        await Promise.all([utils.prepForToken(acc1.address, vaultAddress, "10"), utils.prepForToken(acc2.address, vaultAddress, "20")]);
        await Promise.all([utils.approveWidoForVault(acc1, vaultAddress, wido.address), utils.approveWidoForVault(acc2, vaultAddress, wido.address)]);

        const withdraw = await Promise.all([utils.buildAndSignWithdrawRequest(acc1, {
            user: acc1.address,
            vault: vaultAddress,
            amount: ethers.utils.parseUnits('10', 18).toString(),
            token: underlyingTokenAddress,
            nonce: 0,
            expiration: 1732307386,
        }),
        utils.buildAndSignWithdrawRequest(acc2, {
            user: acc2.address,
            vault: vaultAddress,
            amount: ethers.utils.parseUnits('20', 18).toString(),
            token: underlyingTokenAddress,
            nonce: 0,
            expiration: 1732307386,
        })]);

        const underlyingContract = await utils.getERC20Contract(underlyingTokenAddress, owner);

        expect(await underlyingContract.balanceOf(acc1.address)).to.equal(0);
        expect(await underlyingContract.balanceOf(acc2.address)).to.equal(0);
        await wido.withdrawBatch(withdraw, ethers.constants.AddressZero, "0x00");
        expect(await underlyingContract.balanceOf(acc1.address)).to.equal("10015057821377864158");
        expect(await underlyingContract.balanceOf(acc2.address)).to.equal("20030115642755728317");
        expect(await underlyingContract.balanceOf(wido.address)).to.equal("277843723124228218");
    });

    it("Should withdraw from 3CRV into USDC for two txns", async function () {
        const vaultAddress = "0x84E13785B5a27879921D6F685f041421C7F482dA";
        const [owner, acc1, acc2] = await ethers.getSigners();

        await Promise.all([utils.prepFor3CRV(acc1.address, "2000"), utils.prepFor3CRV(acc2.address, "2000")]);
        await Promise.all([utils.approveWidoForVault(acc1, vaultAddress, wido.address), utils.approveWidoForVault(acc2, vaultAddress, wido.address)]);

        const withdraw = await Promise.all([utils.buildAndSignWithdrawRequest(acc1, {
            user: acc1.address,
            vault: vaultAddress,
            amount: ethers.utils.parseUnits('1500', 18).toString(),
            token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            nonce: 0,
            expiration: 1732307386,
        }),
        utils.buildAndSignWithdrawRequest(acc2, {
            user: acc2.address,
            vault: vaultAddress,
            amount: ethers.utils.parseUnits('500', 18).toString(),
            token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            nonce: 0,
            expiration: 1732307386,
        })]);

        const usdcContract = await utils.getUSDCContract(owner)

        expect(await usdcContract.balanceOf(acc1.address)).to.equal(0);
        expect(await usdcContract.balanceOf(acc2.address)).to.equal(0);
        const callData = "0x89c6973b00000000000000000000000084e13785b5a27879921d6f685f041421c7f482da00000000000000000000000000000000000000000000006c6b935b8bbd400000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007bd0e74a000000000000000000000000e03a338d5c305613afc3877389dd3b061723338700000000000000000000000000000000000000000000000000000000000001200000000000000000000000003ce37278de6388532c3949ce4e886f365b14fb56000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006e4d8f6eb5b000000000000000000000000bebc44782c7db0a1a60cb6fe97d0b483032ff1c700000000000000000000000000000000000000000000006f932707de7f11aaf00000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000007a90bb95000000000000000000000000def1c0ded9bec7f1a1670819833240f027b25eff0000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000588415565b00000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000007bc53b2c00000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003400000000000000000000000000000000000000000000000000000000000000015000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000000000000000000240ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000001142616c616e6365725632000000000000000000000000000000000000000000000000000000000072e4c64c7c2ba49abf000000000000000000000000000000000000000000000000000000007bc53b2c00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000040000000000000000000000000ba12222222228d8ba445958a75a0704d566bf2c806df3b2bbb68adc8b0e302443692037ed9f91b42000000000000000000000063000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000020000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000000000000869584cd000000000000000000000000f4e386b070a18419b5d3af56699f8a438dd18e890000000000000000000000000000000000000000000000b727ffe93a618b813800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        await wido.withdrawBatch(withdraw, "0xd6b88257e91e4E4D4E990B3A858c849EF2DFdE8c", callData);
        expect(await usdcContract.balanceOf(acc1.address)).to.equal("1424835096");
        expect(await usdcContract.balanceOf(acc2.address)).to.equal("474945032");
        expect(await usdcContract.balanceOf(wido.address)).to.equal("198186959");
    });
});
