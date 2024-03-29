// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "../../contracts/core/interfaces/IWidoTokenManager.sol";

abstract contract MainnetForkTest is Test {
    IWidoTokenManager widoTokenManager = IWidoTokenManager(0xF2F02200aEd0028fbB9F183420D3fE6dFd2d3EcD);
    IWidoRouter widoRouter = IWidoRouter(0x7Fb69e8fb1525ceEc03783FFd8a317bafbDfD394);

    address constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant WBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address constant ARB = address(0xB50721BCf8d664c30412Cfbc6cf7a15145234ad1);

    address user1 = vm.addr(1);

    function setUpBase() public {
        uint256 forkId = vm.createFork(vm.rpcUrl("mainnet"));
        vm.selectFork(forkId);

        vm.label(USDC, "USDC");
        vm.label(WETH, "WETH");
        vm.label(WBTC, "WBTC");
        vm.label(ARB, "ARB");
        vm.label(user1, "user1");
    }
}
