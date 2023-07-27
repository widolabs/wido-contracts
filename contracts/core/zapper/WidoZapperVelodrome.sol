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

interface VelodromePair {
    function stable() external pure returns (bool);
}

interface VelodromePairFactory {
    function getFee(bool stable) external pure returns (uint256);
}

interface VelodromeRouter {

    struct route {
        address from;
        address to;
        bool stable;
    }

    function factory() external pure returns (address);

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

    /// @inheritdoc WidoZapperUniswapV2
    function _requires(IUniswapV2Router02 router, IUniswapV2Pair pair)
    internal virtual override {
        // Velodrome pairs do not expose their `factory`
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
    returns (uint256 amountOut) {
        (amountOut,) = VelodromeRouter(address(router)).getAmountOut(amountIn, assetIn.token, assetOut.token);
    }

    /// @inheritdoc WidoZapperUniswapV2
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

    /// @inheritdoc WidoZapperUniswapV2
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

    /// @inheritdoc WidoZapperUniswapV2
    function _feeBps(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        bool //isFromToken0
    ) internal pure virtual override returns (uint256) {
        VelodromePairFactory factory = VelodromePairFactory(VelodromeRouter(address(router)).factory());
        return factory.getFee(VelodromePair(address(pair)).stable());
    }
}
