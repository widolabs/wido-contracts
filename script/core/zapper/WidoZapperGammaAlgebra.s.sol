// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Script.sol";
import "../../../contracts/core/zapper/WidoZapperGammaAlgebra.sol";

contract WidoZapperGammaAlgebraScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        new WidoZapperGammaAlgebra();

        vm.stopBroadcast();
    }
}
