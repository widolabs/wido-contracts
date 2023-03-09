// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "solmate/src/utils/SafeTransferLib.sol";

contract MockSwap {
    using SafeTransferLib for ERC20;
    ERC20 weth;
    ERC20 wbtc;

    constructor(ERC20 _weth, ERC20 _wbtc) {
        weth = _weth;
        wbtc = _wbtc;
    }

    function swapWethToWbtc(uint256 wethAmount, uint256 wbtcAmount, address recepient) external {
        weth.safeTransferFrom(msg.sender, address(this), wethAmount);
        wbtc.safeTransfer(recepient, wbtcAmount);
    }
}
