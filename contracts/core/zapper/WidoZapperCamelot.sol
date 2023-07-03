// SPDX-License-Identifier: GPLv2

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

pragma solidity 0.8.7;

import "./WidoZapperUniswapV2.sol";

interface CamelotRouter {
    function getAmountsOut(uint amountIn, address[] calldata path) external pure returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint deadline
    ) external;
}

/// @title Camelot pools Zapper
/// @notice Add or remove liquidity from CamelotDEX pools using just one of the pool tokens
contract WidoZapperCamelot is WidoZapperUniswapV2 {

    /// @dev This function swap amountIn through the path
    function _swap(
        IUniswapV2Router02 router,
        uint256 amountIn,
        address[] memory path,
        bytes memory //extra
    )
    internal virtual override
    returns (uint256[] memory amounts) {
        amounts = CamelotRouter(address(router)).getAmountsOut(amountIn, path);
        CamelotRouter(address(router)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            1,
            path,
            address(this),
            address(0), // referrer
            block.timestamp
        );
    }
    /// @dev This function computes the amount out for a certain amount in
    function _getAmountOut(
        IUniswapV2Router02 router,
        uint256 amountIn,
        Asset memory assetIn,
        Asset memory assetOut,
        bytes memory //extra
    )
    internal pure virtual override
    returns (uint256) {
        return CamelotRouter(address(router)).quote(amountIn, assetIn.reserves, assetOut.reserves);
    }
}
