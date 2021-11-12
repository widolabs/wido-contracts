const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  const Wido = await ethers.getContractFactory("Wido");
  const wido = await upgrades.deployProxy(Wido, [1]);

  await wido.deployed();

  console.log("Wido deployed to:", wido.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
