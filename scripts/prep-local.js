const hre = require("hardhat");
const utils = require("../test/test-utils");

async function main() {
    const accounts = await ethers.getSigners();

    const waitFor = []
    for (let i = 1; i <= 10; i++) {
        waitFor.push(utils.prepForDai(accounts[i].address, "50000"))
        waitFor.push(utils.prepForUSDC(accounts[i].address, "50000"))
    }
    await Promise.all(waitFor);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
