// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

abstract contract BaseForkTest is Test {
    address constant USDbC = address(0x96AF34c61531883aCfe0f5286a8C87B0806EDC05);

    address user1 = vm.addr(1);

    function setUpBase() public {
        uint256 forkId = vm.createFork(vm.rpcUrl("base"));
        vm.selectFork(forkId);

        vm.label(USDbC, "USDbC");
    }
}
