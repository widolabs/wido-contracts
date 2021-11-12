const { expect } = require("chai");
const { ethers } = require("hardhat");
const hardhatConfig = require("../hardhat.config");
const utils = require("./test-utils");


describe("Wido", function () {
    var wido;
    this.timeout(100000);

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

        const Wido = await ethers.getContractFactory("Wido");
        wido = await Wido.deploy();
        await wido.deployed();
        await wido.initialize(1);
    });

    it("Should deposit USDC into vault for two txns", async function () {
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

        expect(await yUSDCContract.balanceOf(acc1.address)).to.equal(0);
        expect(await yUSDCContract.balanceOf(acc2.address)).to.equal(0);
        await wido.depositPool(deposit, ethers.constants.AddressZero, "0x00");
        expect(await yUSDCContract.balanceOf(acc1.address)).to.equal(63003286);
        expect(await yUSDCContract.balanceOf(acc2.address)).to.equal(77494043);
        expect(await yUSDCContract.balanceOf(wido.address)).to.equal(60341802);
    });

    it("Should deposit USDC into vault - multiple calls", async function () {
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

        expect(await yUSDCContract.balanceOf(acc1.address)).to.equal(0);
        expect(await yUSDCContract.balanceOf(acc2.address)).to.equal(0);
        await wido.depositPool(deposit, ethers.constants.AddressZero, "0x00");


        const deposit1 = await Promise.all([utils.buildAndSignDepositRequest(acc1, {
            user: acc1.address,
            token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            vault: "0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e",
            amount: ethers.utils.parseUnits('100', 6).toString(),
            nonce: 1,
            expiration: 1682307386,
        }),
        utils.buildAndSignDepositRequest(acc2, {
            user: acc2.address,
            token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            vault: "0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e",
            amount: ethers.utils.parseUnits('123', 6).toString(),
            nonce: 1,
            expiration: 1682307386,
        })]);
        await wido.depositPool(deposit1, ethers.constants.AddressZero, "0x00");

        expect(await yUSDCContract.balanceOf(acc1.address)).to.equal(133276182);
        expect(await yUSDCContract.balanceOf(acc2.address)).to.equal(163929706);
        expect(await yUSDCContract.balanceOf(wido.address)).to.equal(104472374);
    });

    it("Should deposit USDC into vault for three txns", async function () {
        const [owner, acc1, acc2, acc3] = await ethers.getSigners();

        await Promise.all([utils.prepForUSDC(acc1.address, "2000"), utils.prepForUSDC(acc2.address, "2000"), utils.prepForUSDC(acc3.address, "2000")]);
        await Promise.all([utils.approveWidoForUSDC(acc1, wido.address), utils.approveWidoForUSDC(acc2, wido.address), utils.approveWidoForUSDC(acc3, wido.address)]);

        const deposit = await Promise.all([
            utils.buildAndSignDepositRequest(acc1, {
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
            }),
            utils.buildAndSignDepositRequest(acc3, {
                user: acc3.address,
                token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
                vault: "0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e",
                amount: ethers.utils.parseUnits('1000', 6).toString(),
                nonce: 0,
                expiration: 1682307386,
            })
        ]);

        const yUSDCContract = await hre.ethers.getVerifiedContractAt("0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e");

        expect(await yUSDCContract.balanceOf(acc1.address)).to.equal(0);
        expect(await yUSDCContract.balanceOf(acc2.address)).to.equal(0);
        expect(await yUSDCContract.balanceOf(acc3.address)).to.equal(0);
        await wido.depositPool(deposit, ethers.constants.AddressZero, "0x00");
        expect(await yUSDCContract.balanceOf(acc1.address)).to.equal(85864879);
        expect(await yUSDCContract.balanceOf(acc2.address)).to.equal(105613801);
        expect(await yUSDCContract.balanceOf(acc3.address)).to.equal(858648794);
    });


    it("Should deposit DAI into vault for two txns", async function () {
        const [owner, acc1, acc2] = await ethers.getSigners();

        await Promise.all([utils.prepForDai(acc1.address, "2000"), utils.prepForDai(acc2.address, "2000")]);
        await Promise.all([utils.approveWidoForDai(acc1, wido.address), utils.approveWidoForDai(acc2, wido.address)]);

        const deposit = await Promise.all([
            utils.buildAndSignDepositRequest(acc1, {
                user: acc1.address,
                token: "0x6b175474e89094c44da98b954eedeac495271d0f",
                vault: "0xdA816459F1AB5631232FE5e97a05BBBb94970c95",
                amount: ethers.utils.parseUnits('100', 18).toString(),
                nonce: 0,
                expiration: 1682307386,
            }),
            utils.buildAndSignDepositRequest(acc2, {
                user: acc2.address,
                token: "0x6b175474e89094c44da98b954eedeac495271d0f",
                vault: "0xdA816459F1AB5631232FE5e97a05BBBb94970c95",
                amount: ethers.utils.parseUnits('123', 18).toString(),
                nonce: 0,
                expiration: 1682307386,
            })]);

        const yDaiContract = await hre.ethers.getVerifiedContractAt("0xdA816459F1AB5631232FE5e97a05BBBb94970c95");

        expect(await yDaiContract.balanceOf(acc1.address)).to.equal(0);
        expect(await yDaiContract.balanceOf(acc2.address)).to.equal(0);
        await wido.depositPool(deposit, ethers.constants.AddressZero, "0x00");
        expect(await yDaiContract.balanceOf(acc1.address)).to.equal("76943654910670319865");
        expect(await yDaiContract.balanceOf(acc2.address)).to.equal("94640695540124493434");
    });

    it("Should deposit DAI into vault for two txns - First user 50% Take", async function () {
        const [owner, acc1, acc2] = await ethers.getSigners();

        await Promise.all([utils.prepForDai(acc1.address, "2000"), utils.prepForDai(acc2.address, "2000")]);
        await Promise.all([utils.approveWidoForDai(acc1, wido.address), utils.approveWidoForDai(acc2, wido.address)]);
        await wido.setFirstUserTakeRate(5000);

        const deposit = await Promise.all([
            utils.buildAndSignDepositRequest(acc1, {
                user: acc1.address,
                token: "0x6b175474e89094c44da98b954eedeac495271d0f",
                vault: "0xdA816459F1AB5631232FE5e97a05BBBb94970c95",
                amount: ethers.utils.parseUnits('100', 18).toString(),
                nonce: 0,
                expiration: 1682307386,
            }),
            utils.buildAndSignDepositRequest(acc2, {
                user: acc2.address,
                token: "0x6b175474e89094c44da98b954eedeac495271d0f",
                vault: "0xdA816459F1AB5631232FE5e97a05BBBb94970c95",
                amount: ethers.utils.parseUnits('123', 18).toString(),
                nonce: 0,
                expiration: 1682307386,
            })]);

        const yDaiContract = await hre.ethers.getVerifiedContractAt("0xdA816459F1AB5631232FE5e97a05BBBb94970c95");

        expect(await yDaiContract.balanceOf(acc1.address)).to.equal(0);
        expect(await yDaiContract.balanceOf(acc2.address)).to.equal(0);
        await wido.depositPool(deposit, ethers.constants.AddressZero, "0x00");
        expect(await yDaiContract.balanceOf(acc1.address)).to.equal("90001965999820288518");
        expect(await yDaiContract.balanceOf(acc2.address)).to.equal("97360255756794737498");
    });

    it("Should deposit DAI into vault for two txns - First user 100% Take", async function () {
        const [owner, acc1, acc2] = await ethers.getSigners();

        await Promise.all([utils.prepForDai(acc1.address, "2000"), utils.prepForDai(acc2.address, "2000")]);
        await Promise.all([utils.approveWidoForDai(acc1, wido.address), utils.approveWidoForDai(acc2, wido.address)]);
        await wido.setFirstUserTakeRate(10000);

        const deposit = await Promise.all([
            utils.buildAndSignDepositRequest(acc1, {
                user: acc1.address,
                token: "0x6b175474e89094c44da98b954eedeac495271d0f",
                vault: "0xdA816459F1AB5631232FE5e97a05BBBb94970c95",
                amount: ethers.utils.parseUnits('100', 18).toString(),
                nonce: 0,
                expiration: 1682307386,
            }),
            utils.buildAndSignDepositRequest(acc2, {
                user: acc2.address,
                token: "0x6b175474e89094c44da98b954eedeac495271d0f",
                vault: "0xdA816459F1AB5631232FE5e97a05BBBb94970c95",
                amount: ethers.utils.parseUnits('123', 18).toString(),
                nonce: 0,
                expiration: 1682307386,
            })]);

        const yDaiContract = await hre.ethers.getVerifiedContractAt("0xdA816459F1AB5631232FE5e97a05BBBb94970c95");

        expect(await yDaiContract.balanceOf(acc1.address)).to.equal(0);
        expect(await yDaiContract.balanceOf(acc2.address)).to.equal(0);
        await wido.depositPool(deposit, ethers.constants.AddressZero, "0x00");
        expect(await yDaiContract.balanceOf(acc1.address)).to.equal("79154679477068892275");
        expect(await yDaiContract.balanceOf(acc2.address)).to.equal("97360255756794737498");
    });

    it("Should fail with not enough funds", async function () {
        const [owner, acc1, acc2] = await ethers.getSigners();

        await Promise.all([utils.prepForDai(acc1.address, "2000"), utils.prepForDai(acc2.address, "2000")]);
        await Promise.all([utils.approveWidoForDai(acc1, wido.address), utils.approveWidoForDai(acc2, wido.address)]);

        const deposit = await Promise.all([
            utils.buildAndSignDepositRequest(acc1, {
                user: acc1.address,
                token: "0x6b175474e89094c44da98b954eedeac495271d0f",
                vault: "0xdA816459F1AB5631232FE5e97a05BBBb94970c95",
                amount: ethers.utils.parseUnits('100', 18).toString(),
                nonce: 0,
                expiration: 1682307386,
            }),
            utils.buildAndSignDepositRequest(acc2, {
                user: acc2.address,
                token: "0x6b175474e89094c44da98b954eedeac495271d0f",
                vault: "0xdA816459F1AB5631232FE5e97a05BBBb94970c95",
                amount: ethers.utils.parseUnits('2800', 18).toString(),
                nonce: 0,
                expiration: 1682307386,
            })]);

        const yDaiContract = await hre.ethers.getVerifiedContractAt("0xdA816459F1AB5631232FE5e97a05BBBb94970c95");

        expect(await yDaiContract.balanceOf(acc1.address)).to.equal(0);
        expect(await yDaiContract.balanceOf(acc2.address)).to.equal(0);
        await expect(wido.depositPool(deposit, ethers.constants.AddressZero, "0x00")).to.be.revertedWith("Dai/insufficient-balance");
    });

    it("Should fail with invalid nonce", async function () {
        const [owner, acc1, acc2] = await ethers.getSigners();

        await Promise.all([utils.prepForDai(acc1.address, "2000"), utils.prepForDai(acc2.address, "2000")]);
        await Promise.all([utils.approveWidoForDai(acc1, wido.address), utils.approveWidoForDai(acc2, wido.address)]);

        const deposit = await Promise.all([
            utils.buildAndSignDepositRequest(acc1, {
                user: acc1.address,
                token: "0x6b175474e89094c44da98b954eedeac495271d0f",
                vault: "0xdA816459F1AB5631232FE5e97a05BBBb94970c95",
                amount: ethers.utils.parseUnits('100', 18).toString(),
                nonce: 1,
                expiration: 1682307386,
            }),
            utils.buildAndSignDepositRequest(acc2, {
                user: acc2.address,
                token: "0x6b175474e89094c44da98b954eedeac495271d0f",
                vault: "0xdA816459F1AB5631232FE5e97a05BBBb94970c95",
                amount: ethers.utils.parseUnits('1800', 18).toString(),
                nonce: 0,
                expiration: 1682307386,
            })]);

        const yDaiContract = await hre.ethers.getVerifiedContractAt("0xdA816459F1AB5631232FE5e97a05BBBb94970c95");

        expect(await yDaiContract.balanceOf(acc1.address)).to.equal(0);
        expect(await yDaiContract.balanceOf(acc2.address)).to.equal(0);
        await expect(wido.depositPool(deposit, ethers.constants.AddressZero, "0x00")).to.be.revertedWith("Invalid nonce");
    });

    it("Should deposit USDC into 3CRV for two txns", async function () {
        const [owner, acc1, acc2] = await ethers.getSigners();

        await Promise.all([utils.prepForUSDC(acc1.address, "2000"), utils.prepForUSDC(acc2.address, "2000")]);
        await Promise.all([utils.approveWidoForUSDC(acc1, wido.address), utils.approveWidoForUSDC(acc2, wido.address)]);

        const deposit = await Promise.all([utils.buildAndSignDepositRequest(acc1, {
            user: acc1.address,
            token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            vault: "0x84E13785B5a27879921D6F685f041421C7F482dA",
            amount: ethers.utils.parseUnits('100', 6).toString(),
            nonce: 0,
            expiration: 1732307386,
        }),
        utils.buildAndSignDepositRequest(acc2, {
            user: acc2.address,
            token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            vault: "0x84E13785B5a27879921D6F685f041421C7F482dA",
            amount: ethers.utils.parseUnits('123', 6).toString(),
            nonce: 0,
            expiration: 1732307386,
        })]);

        const y3crvContract = await hre.ethers.getVerifiedContractAt("0x84E13785B5a27879921D6F685f041421C7F482dA");

        expect(await y3crvContract.balanceOf(acc1.address)).to.equal(0);
        expect(await y3crvContract.balanceOf(acc2.address)).to.equal(0);
        const callData = "0x38b32e68000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000d4ab5c000000000000000000000000084e13785b5a27879921d6f685f041421c7f482da0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b54e603598db0ea920000000000000000000000006c3f90f043a72fa612cbac8115ee7e52bde6e4900000000000000000000000005ce9b49b7a1be9f2c3dc2b2a5bacea56fa21fbee00000000000000000000000000000000000000000000000000000000000001600000000000000000000000003ce37278de6388532c3949ce4e886f365b14fb560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000026464c98c6c000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000bebc44782c7db0a1a60cb6fe97d0b483032ff1c7000000000000000000000000000000000000000000000000000000000d4ab5c000000000000000000000000000000000000000000000000ba94d97b07fc6017c000000000000000000000000def1c0ded9bec7f1a1670819833240f027b25eff000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000128d9627aa40000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000d4ab5c0000000000000000000000000000000000000000000000000000000000d2532e500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7869584cd000000000000000000000000f4e386b070a18419b5d3af56699f8a438dd18e8900000000000000000000000000000000000000000000004b77c63b72618e789200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        await wido.depositPool(deposit, "0x92be6adb6a12da0ca607f9d87db2f9978cd6ec3e", callData);
        expect(await y3crvContract.balanceOf(acc1.address)).to.equal("42334203286683382385");
        expect(await y3crvContract.balanceOf(acc2.address)).to.equal("52071070042620560333");
        expect(await y3crvContract.balanceOf(wido.address)).to.equal("118244988816501908053");
    });
});
