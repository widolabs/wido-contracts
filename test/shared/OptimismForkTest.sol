// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

abstract contract OptimismForkTest is Test {
    address constant WBTC = address(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    address constant WETH = address(0x4200000000000000000000000000000000000006);
    address constant USDC = address(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    address constant DOLA = address(0x8aE125E8653821E851F12A49F7765db9a9ce7384);
    address constant FRAX = address(0x2E3D870790dC77A83DD1d18184Acc7439A53f475);
    address constant WTBT = address(0xdb4eA87fF83eB1c80b8976FC47731Da6a31D35e5);

    address user1 = vm.addr(1);

    function setUpBase() public {
        uint256 forkId = vm.createFork(vm.rpcUrl("optimism"));
        vm.selectFork(forkId);

        vm.label(USDC, "USDC");
        vm.label(WETH, "WETH");
        vm.label(WBTC, "WBTC");
        vm.label(DOLA, "DOLA");
        vm.label(FRAX, "FRAX");
        vm.label(WTBT, "WTBT");
    }
}
