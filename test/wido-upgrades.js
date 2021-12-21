const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");

describe("WidoProxy", function () {
    this.timeout(100000);

    it('works before and after upgrading', async function () {
        const Wido = await ethers.getContractFactory("Wido");
        const instance = await upgrades.deployProxy(Wido, [42]);
        const domainSeparator = await instance.DOMAIN_SEPARATOR();

        const WidoV2 = await ethers.getContractFactory("Wido");
        await upgrades.upgradeProxy(instance.address, WidoV2);
        expect(await instance.DOMAIN_SEPARATOR()).to.equal(domainSeparator);
    });
});