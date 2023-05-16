// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Script.sol";
import "../contracts/WidoCollateralSwap.sol";

contract WidoFlashLoanScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        //WidoFlashLoan wfl = new WidoFlashLoan(
        //// TODO
        //);

        vm.stopBroadcast();
    }
}
