// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

abstract contract BSCForkTest is Test {
    address constant USDC = address(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);

    address user1 = vm.addr(1);

    function setUpBase() public {
        uint256 forkId = vm.createFork(vm.rpcUrl("bsc"));
        vm.selectFork(forkId);

        vm.label(USDC, "USDC");
    }
}
