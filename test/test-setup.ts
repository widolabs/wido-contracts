require("ts-node/register");
require("hardhat/register");

import {ChainName, getChainId, Protocol, useLocalApi} from "wido";
import {getSupportedTokensInternal} from "wido/src/get-supported-tokens-internal";
import {useLocalApi as useLocalApiInternal} from "wido/src/config";

if (process.env.LOCAL) {
  useLocalApi();
  useLocalApiInternal();
}

if (!process.version.includes("v18")) {
  // eslint-disable-next-line no-console
  console.log(`Fetch API not available on ${process.version}. Patching with cross-fetch...`);
  global.fetch = require("cross-fetch");
}

const chainId = getChainId(process.env.HARDHAT_FORK as ChainName);

const protocol = process.env.PROTOCOL ? (process.env.PROTOCOL.split(",") as Protocol[]) : [];

try {
  // suppress warning for top level await
  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-ignore
  const tokens = await getSupportedTokensInternal({
    chainId: [chainId],
    protocol,
    includePreview: true,
  });

  global.supportedTokens = tokens;
} catch (err) {
  console.log("📜 LOG > test-setup.ts", "Cannot fetch supported tokens.", err);
  global.supportedTokens = [];
}
