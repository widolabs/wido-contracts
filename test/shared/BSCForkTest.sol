// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

abstract contract BSCForkTest is Test {
    address constant USDC = address(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    address constant WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address constant BUSD = address(0x55d398326f99059fF775485246999027B3197955);

    address user1 = vm.addr(1);

    function setUpBase() public {
        uint256 forkId = vm.createFork(vm.rpcUrl("bsc"));
        vm.selectFork(forkId);

        vm.label(USDC, "USDC");
        vm.label(WBNB, "WBNB");
        vm.label(BUSD, "BUSD");
    }
}
