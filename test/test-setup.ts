require("ts-node/register");
require("hardhat/register");

if (!process.version.includes("v18")) {
  // eslint-disable-next-line no-console
  console.log(`Fetch API not available on ${process.version}. Patching with cross-fetch...`);
  global.fetch = require("cross-fetch");
}
