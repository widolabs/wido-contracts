// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Script.sol";
import "../../../contracts/core/zapper/WidoZapperUniswapV3.sol";

contract WidoZapperUniswapV3Script is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        new WidoZapperUniswapV3();

        vm.stopBroadcast();
    }
}
