// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Script.sol";
import "../contracts/WidoCollateralSwap_Aave.sol";
import "../contracts/WidoCollateralSwap_ERC3156.sol";

contract WidoFlashLoanScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        if (block.chainid == 1) {
            // Mainnet
            WidoCollateralSwap_Aave wfl_aave = new WidoCollateralSwap_Aave(
                IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e)
            );
            WidoCollateralSwap_ERC3156 wfl_equalizer = new WidoCollateralSwap_ERC3156(
                IERC3156FlashLender(0x4EAF187ad4cE325bF6C84070b51c2f7224A51321)
            );
        }
        else if (block.chainid == 137) {
            // Polygon
            WidoCollateralSwap_Aave wfl_aave = new WidoCollateralSwap_Aave(
                IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb)
            );
            WidoCollateralSwap_ERC3156 wfl_equalizer = new WidoCollateralSwap_ERC3156(
                IERC3156FlashLender(0xBD332e2f7240487db5cAB355A9cDd945Fe2234C9)
            );
        }
        else if (block.chainid == 42161) {
            // Arbitrum
            WidoCollateralSwap_Aave wfl_aave = new WidoCollateralSwap_Aave(
                IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb)
            );
        }
        else {
            revert("Not implemented");
        }

        vm.stopBroadcast();
    }
}
