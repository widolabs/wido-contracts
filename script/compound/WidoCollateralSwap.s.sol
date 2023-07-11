// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Script.sol";
import "../../contracts/compound/WidoCollateralSwap_Aave.sol";
import "../../contracts/compound/WidoCollateralSwap_ERC3156.sol";

contract WidoFlashLoanScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // Mainnet
        if (block.chainid == 1) {
            // Aave
            new WidoCollateralSwap_Aave(
                IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e)
            );
            // Equalizer
            new WidoCollateralSwap_ERC3156(
                IERC3156FlashLender(0x4EAF187ad4cE325bF6C84070b51c2f7224A51321)
            );
        }
        // Polygon
        else if (block.chainid == 137) {
            // Aave
            new WidoCollateralSwap_Aave(
                IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb)
            );
            // Equalizer
            new WidoCollateralSwap_ERC3156(
                IERC3156FlashLender(0xBD332e2f7240487db5cAB355A9cDd945Fe2234C9)
            );
        }
        // Arbitrum
        else if (block.chainid == 42161) {
            // Aave
            new WidoCollateralSwap_Aave(
                IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb)
            );
        }
        else {
            revert("Not implemented");
        }

        vm.stopBroadcast();
    }
}
