// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "../../contracts/core/interfaces/IWidoTokenManager.sol";

abstract contract PolygonForkTest is Test {
    address constant WETH = address(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    address constant USDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

    address user1 = vm.addr(1);

    function setUpBase() public {
        uint256 forkId = vm.createFork(vm.rpcUrl("polygon"));
        vm.selectFork(forkId);

        vm.label(USDC, "USDC");
        vm.label(WETH, "WETH");
    }
}
