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
                IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e),
                IComet(0xc3d688B66703497DAA19211EEdff47f25384cdc3) // cUSDCv3
            );
            new WidoCollateralSwap_Aave(
                IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e),
                IComet(0xA17581A9E3356d9A858b789D68B4d866e593aE94) // cWETHv3
            );
            // Equalizer
            // new WidoCollateralSwap_ERC3156(
            //     IERC3156FlashLender(0x4EAF187ad4cE325bF6C84070b51c2f7224A51321)
            // );
        }
        // Polygon
        else if (block.chainid == 137) {
            // Aave
            new WidoCollateralSwap_Aave(
                IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb),
                IComet(0xF25212E676D1F7F89Cd72fFEe66158f541246445) // cUSDCv3
            );
            // Equalizer
            // new WidoCollateralSwap_ERC3156(
            //     IERC3156FlashLender(0xBD332e2f7240487db5cAB355A9cDd945Fe2234C9)
            // );
        }
        // Arbitrum
        else if (block.chainid == 42161) {
            // Aave
            new WidoCollateralSwap_Aave(
                IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb),
                IComet(0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA) // cUSDCv3
            );
        }
        else {
            revert("Not implemented");
        }

        vm.stopBroadcast();
    }
}
