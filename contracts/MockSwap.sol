// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "solmate/src/utils/SafeTransferLib.sol";

contract MockSwap {
    using SafeTransferLib for ERC20;
    ERC20 immutable weth;
    ERC20 immutable wbtc;

    constructor(ERC20 _weth, ERC20 _wbtc) {
        weth = _weth;
        wbtc = _wbtc;
    }

    function swapWbtcToWeth(uint256 wbtcAmount, uint256 wethAmount, address recipient) external {
        wbtc.safeTransferFrom(msg.sender, address(this), wbtcAmount);
        weth.safeTransfer(recipient, wethAmount);
    }
}
