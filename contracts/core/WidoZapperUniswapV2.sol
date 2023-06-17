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

import "./WidoZapper.sol";

/// @title UniswapV2 pools Zapper
/// @notice Add or remove liquidity from Uniswap V2 pools using just one of the pool tokens
contract WidoZapperUniswapV2 is WidoZapper {

    /// @dev This function checks that the pair belongs to the factory
    function _requires(IUniswapV2Router02 router, IUniswapV2Pair pair)
    internal virtual override {
        require(pair.factory() == router.factory(), "Incompatible router and pair");
    }

    /// @dev This function quotes the expected amountB given a certain amountA, while the pool has the specified reserves
    function _quote(IUniswapV2Router02 router, uint256 amountA, uint256 reserveA, uint256 reserveB)
    internal pure virtual override
    returns (uint256 amountB) {
        return router.quote(amountA, reserveA, reserveB);
    }

    /// @dev This function computes the amount out for a certain amount in
    function _getAmountOut(IUniswapV2Router02 router, uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
    internal pure virtual override
    returns (uint256 amountOut) {
        return router.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /// @dev This function adds liquidity into the pool
    function _addLiquidity(
        IUniswapV2Router02 router,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        bytes memory //extra
    )
    internal virtual override
    returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        return router.addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    /// @dev This function swap amountIn through the path
    function _swap(
        IUniswapV2Router02 router,
        uint256 amountIn,
        address[] memory path,
        bytes memory //extra
    )
    internal virtual override
    returns (uint256[] memory amounts) {
        return router.swapExactTokensForTokens(
            amountIn,
            1,
            path,
            address(this),
            block.timestamp
        );
    }
}
