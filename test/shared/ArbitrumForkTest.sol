// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

abstract contract ArbitrumForkTest is Test {
    address constant WETH = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    address constant USDC = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address constant ARB = address(0x912CE59144191C1204E64559FE8253a0e49E6548);

    address user1 = vm.addr(1);

    function setUpBase() public {
        uint256 forkId = vm.createFork(vm.rpcUrl("arbitrum"));
        vm.selectFork(forkId);

        vm.label(USDC, "USDC");
        vm.label(WETH, "WETH");
        vm.label(ARB, "ARB");
    }
}
