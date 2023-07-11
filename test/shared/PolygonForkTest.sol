// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

abstract contract PolygonForkTest is Test {
    address constant WETH = address(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    address constant USDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    address constant WMATIC = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    address constant QUICK = address(0xB5C064F955D8e7F38fE0460C556a72987494eE17);

    address user1 = vm.addr(1);

    function setUpBase() public {
        uint256 forkId = vm.createFork(vm.rpcUrl("polygon"));
        vm.selectFork(forkId);

        vm.label(USDC, "USDC");
        vm.label(WETH, "WETH");
        vm.label(WMATIC, "WMATIC");
        vm.label(QUICK, "QUICK");
    }
}
