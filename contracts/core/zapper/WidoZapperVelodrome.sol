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

interface VelodromeRouter {

    struct route {
        address from;
        address to;
        bool stable;
    }

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external pure returns (uint amount, bool stable);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

/// @title Velodrome pools Zapper
/// @notice Add or remove liquidity from Velodrome pools using just one of the pool tokens
contract WidoZapperVelodrome is WidoZapperUniswapV2 {

    /// @dev This function checks that the pair belongs to the factory
    function _requires(IUniswapV2Router02 router, IUniswapV2Pair pair)
    internal virtual override {
        // Velodrome pairs do not expose their `factory`
    }

    /// @dev This function quotes the expected amountB given a certain amountA, while the pool has the specified reserves
    ///  code is copied here from the VelodromeRouter because the function is defined as internal
    ///  https://github.com/velodrome-finance/contracts/blob/master/contracts/Router.sol#L58
    function _quote(
        IUniswapV2Router02, //router
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    )
    internal pure virtual override
    returns (uint256 amountB) {
        require(amountA > 0, 'Router: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'Router: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
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
    returns (uint256 amountOut) {
        (amountOut,) = VelodromeRouter(address(router)).getAmountOut(amountIn, assetIn.token, assetOut.token);
    }

    /// @dev This function adds liquidity into the pool
    function _addLiquidity(
        IUniswapV2Router02 router,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        bytes memory extra
    )
    internal virtual override
    returns (uint256 liquidity) {
        (,, liquidity) = VelodromeRouter(address(router)).addLiquidity(
            tokenA,
            tokenB,
            abi.decode(extra, (bool)), // stable
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
        address tokenIn,
        address tokenOut,
        bytes memory extra
    )
    internal virtual override
    returns (uint256 amountOut) {
        VelodromeRouter.route[] memory routes = new VelodromeRouter.route[](1);
            routes[0] = VelodromeRouter.route({
            from : tokenIn,
            to : tokenOut,
            stable : abi.decode(extra, (bool))
        });
        uint256[] memory amounts = VelodromeRouter(address(router)).swapExactTokensForTokens(
            amountIn,
            1,
            routes,
            address(this),
            block.timestamp
        );
        amountOut = amounts[1];
    }
}
