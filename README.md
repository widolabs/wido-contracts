# Wido Contracts

This repo contains smart contracts for the [Wido Router](https://docs.joinwido.com/) ecosystem. [Reach out](https://www.joinwido.com/contact) in case of any questions.

## Wido Router

Wido Router is a cross-chain transaction layer powered by [LayerZero](https://layerzero.network/).

Wido Router enables cross-chain deposits and withdrawals in a single transaction. The user does not need the destination chain native token to pay for gas.

You can [watch it in action](https://showcase.ethglobal.com/hackmoney2022/wido-swap-7wvas) (video, 4 minutes) or [try it live](https://app.joinwido.com/router).

**Deployed Contracts**
* Wido Router on mainnet Ethereum: [`0xB8F77519cD414CB1849e4b7B4824183629F6B239`](https://etherscan.io/address/0xB8F77519cD414CB1849e4b7B4824183629F6B239)
* Wido Router on Fantom: [`0x7Bbd6348db83C2fb3633Eebb70367E1AEc258764`](https://ftmscan.com/address/0x7bbd6348db83c2fb3633eebb70367e1aec258764)
* Wido Router on Avalanche: [`0x7Bbd6348db83C2fb3633Eebb70367E1AEc258764`](https://snowtrace.io/address/0x7Bbd6348db83C2fb3633Eebb70367E1AEc258764)


## Wido Batches
Batches allow users to save up to 90% in gas on Ethereum L1. Instead of sending a costly transaction on your own, you can batch it with other people and split the gas. [Learn how it works](https://www.joinwido.com/blog/how-to-save-90-in-gas-on-ethereum).

Wido Batches can be combined with [Wido Router](#wido-router) to enable cross-chain transaction batching. Users are able to deposit to smart contracts on different chains while saving in gas.

**Deployed contracts**

Wido Batch contracts can be found on mainnet Ethereum on the following addresses:

* Wido.sol: [`0x7Bbd6348db83C2fb3633Eebb70367E1AEc258764`](https://etherscan.io/address/0x7Bbd6348db83C2fb3633Eebb70367E1AEc258764)
* WidoSwap.sol: [`0x926D47CBf3ED22872F8678d050e70b198bAE1559`](https://etherscan.io/address/0x926d47cbf3ed22872f8678d050e70b198bae1559)
* WidoWithdraw.sol: [`0xeC551adFd927a0a2FB680e984B452516a7B2cCbc`](https://etherscan.io/address/0xeC551adFd927a0a2FB680e984B452516a7B2cCbc)

## Try Wido locally
```shell
npm run install
```
In order to work on this project you need to set the following enviroment variables:

```
ETHERSCAN_API_KEY=
MAINNET_ARCHIVE_NODE_URL=
ROPSTEN_NODE_URL=
GOERLI_NODE_URL=
MAINNET_NODE_URL=
ROPSTEN_PKEY=
GOERLI_PKEY=
MAINNET_PKEY=
```

**Running tests**
```shell
npx hardhat test
```

## Support

[Please reach out!](https://www.joinwido.com/contact)