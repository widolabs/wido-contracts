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
                IComet(0xc3d688B66703497DAA19211EEdff47f25384cdc3), // cUSDCv3
                address(0x7Fb69e8fb1525ceEc03783FFd8a317bafbDfD394), // Wido Router
                address(0xF2F02200aEd0028fbB9F183420D3fE6dFd2d3EcD) // Wido Token Manager
            );
            new WidoCollateralSwap_Aave(
                IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e),
                IComet(0xA17581A9E3356d9A858b789D68B4d866e593aE94), // cWETHv3
                address(0x7Fb69e8fb1525ceEc03783FFd8a317bafbDfD394), // Wido Router
                address(0xF2F02200aEd0028fbB9F183420D3fE6dFd2d3EcD) // Wido Token Manager
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
                IComet(0xF25212E676D1F7F89Cd72fFEe66158f541246445), // cUSDCv3
                address(0x919dF3aDbF5cfC9fcfd43198EDFe5aA5561CB456), // Wido Router
                address(0x4Eedfb447a7a0bec51145590C63c1B751e8C745c) // Wido Token Manager
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
                IComet(0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA), // cUSDCv3
                address(0x6196Ac4C950817D23918bB643f4d315Ebe0A09b1), // Wido Router
                address(0x179B7F6178862B33429f515b532D6cd64f61eaEb) // Wido Token Manager
            );
        }
        else {
            revert("Not implemented");
        }

        vm.stopBroadcast();
    }
}
