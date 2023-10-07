// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "solmate/src/utils/SafeTransferLib.sol";

contract MockSwap {
    using SafeTransferLib for ERC20;
    ERC20 immutable weth;
    ERC20 immutable wbtc;
    ERC20 immutable usdc;

    constructor(ERC20 _weth, ERC20 _wbtc, ERC20 _usdc) {
        weth = _weth;
        wbtc = _wbtc;
        usdc = _usdc;
    }

    function swapWbtcToWeth(uint256 wbtcAmount, uint256 wethAmount, address recipient) external {
        wbtc.safeTransferFrom(msg.sender, address(this), wbtcAmount);
        weth.safeTransfer(recipient, wethAmount);
    }

    function swapWbtcToUsdc(uint256 wbtcAmount, uint256 usdcAmount, address recipient) external {
        wbtc.safeTransferFrom(msg.sender, address(this), wbtcAmount);
        usdc.safeTransfer(recipient, usdcAmount);
    }
}
