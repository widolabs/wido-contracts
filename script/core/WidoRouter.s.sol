// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Script.sol";
import "../../contracts/core/WidoRouter.sol";

contract WidoRouterScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        address wrappedNativeAddress;
        address bank = address(0x5EF7F250f74d4F11A68054AE4e150705474a6D4a);

        // Base
        if (block.chainid == 8453) {
            wrappedNativeAddress = address(0x4200000000000000000000000000000000000006);
        }
        else {
            revert("Not implemented");
        }

        new WidoRouter(wrappedNativeAddress, bank);

        vm.stopBroadcast();
    }
}
