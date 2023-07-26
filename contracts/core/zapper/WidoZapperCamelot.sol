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

interface CamelotPair {
    function FEE_DENOMINATOR() external pure returns (uint256);

    function token0FeePercent() external pure returns (uint16);

    function token1FeePercent() external pure returns (uint16);
}

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

    /// @inheritdoc WidoZapperUniswapV2
    function _swap(
        IUniswapV2Router02 router,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        bytes memory //extra
    )
    internal virtual override
    returns (uint256 amountOut) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        uint256[] memory amounts = CamelotRouter(address(router)).getAmountsOut(amountIn, path);
        amountOut = amounts[1];
        CamelotRouter(address(router)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            1,
            path,
            address(this),
            address(0), // referrer
            block.timestamp
        );
    }

    /// @inheritdoc WidoZapperUniswapV2
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

    /// @inheritdoc WidoZapperUniswapV2
    function _feeBps(
        IUniswapV2Pair pair,
        bool isFromToken0
    ) internal pure virtual override returns (uint256) {
        if (isFromToken0) {
            return uint256(CamelotPair(address(pair)).token0FeePercent()) * 1000 / CamelotPair(address(pair)).FEE_DENOMINATOR();
        }
        else {
            return uint256(CamelotPair(address(pair)).token1FeePercent()) * 1000 / CamelotPair(address(pair)).FEE_DENOMINATOR();
        }
    }
}
