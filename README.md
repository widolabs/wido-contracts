# Wido Contracts

## Wido Router
Wido Router, enabled by [LayerZero](https://layerzero.network/), is a cross-chain deposit and withdrawal protocol. Wido Router allows users to deposit into vaults (or farms, pools, collateralised positions, NFTs and more) on different chains in a single transaction. The user does not need the destination chain native token to pay for gas.

Learn more about it: https://docs.joinwido.com

## Wido Batches
Batches allow users to save upto 90% in gas on Ethereum L1. Instead of sending a costly transaction on your own, you can batch it with other people and split the gas.

### Deployed Contracts
Wido.sol: [`0x7Bbd6348db83C2fb3633Eebb70367E1AEc258764`](https://etherscan.io/address/0x7Bbd6348db83C2fb3633Eebb70367E1AEc258764)  
WidoSwap.sol: [`0x926D47CBf3ED22872F8678d050e70b198bAE1559`](https://etherscan.io/address/0x926d47cbf3ed22872f8678d050e70b198bae1559)
WidoWithdraw.sol: [`0xeC551adFd927a0a2FB680e984B452516a7B2cCbc`](https://etherscan.io/address/0xeC551adFd927a0a2FB680e984B452516a7B2cCbc)

## Install packages
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

## Running tests
```shell
npx hardhat test
```

## Running a local hardhat node
We need two terminals window to setup local environment

In the first one, let's bring a hardhat node forking Ethereum mainnet
```shell
npx hardhat node
```

In the second one, let's deploy Wido contract and also send some USDC to test accounts
```shell
npm run prep-local
```

## Connecting to local hardhat node
Add a new custom network to Metamask with the following settings

Network Name: Fork Hardhat (you can change it to anything)  
RPC URL: http://127.0.0.1:8545/  
Chain ID: 1 (Since we forked Ethereum mainnet)  

Unsure on how to add custom network, follow [this](https://metamask.zendesk.com/hc/en-us/articles/360043227612-How-to-add-a-custom-network-RPC) guide.


## Add test accounts to metamask
Following is the private key of few test accounts to import into Metamask. [Guide to importing accounts in Metamask](https://metamask.zendesk.com/hc/en-us/articles/360015489331-How-to-import-an-Account)

Account #1: 0x70997970c51812dc3a010c7d01b50e0d17dc79c8  
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

Account #2: 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc  
Private Key: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

Account #3: 0x90f79bf6eb2c4f870365e785982e1f101e93b906  
Private Key: 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6

The above accounts will have 50000 USDC after running `npm run prep-local`


## Others
Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/sample-script.js
npx hardhat help
```
