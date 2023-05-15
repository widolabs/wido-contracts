// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Scrow.sol";
import "../contracts/WidoFlashLoan.sol";

contract FlashLoanScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        WidoFlashLoan wfl = new WidoFlashLoan(
        // TODO
        );

        vm.stopBroadcast();
    }
}
