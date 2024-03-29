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

import "./WidoZapperVelodromeV1.sol";

interface IPoolFactory {
    function getFee(address _pool, bool _stable) external pure returns (uint256);
}

interface VelodromeV2Pair {
    function factory() external pure returns (address);
}

interface VelodromeV2Router {

    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function defaultFactory() external pure returns (address);

    function getAmountsOut(uint256 amountIn, Route[] memory routes) external pure returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        Route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

/// @title VelodromeV2 pools Zapper
/// @notice Add or remove liquidity from Velodrome V2 pools using just one of the pool tokens
contract WidoZapperVelodromeV2 is WidoZapperVelodromeV1 {

    /// @inheritdoc WidoZapperUniswapV2
    function _requires(IUniswapV2Router02 router, IUniswapV2Pair pair)
    internal virtual override {
        require(pair.factory() == VelodromeV2Router(address(router)).defaultFactory(), "Incompatible router and pair");
    }

    /// @inheritdoc WidoZapperUniswapV2
    function _getAmountOut(
        IUniswapV2Router02 router,
        IUniswapV2Pair, //pair
        uint256 amountIn,
        Asset memory assetIn,
        Asset memory assetOut,
        bytes memory extra
    )
    internal view virtual override
    returns (uint256 amountOut) {
        VelodromeV2Router.Route[] memory routes = new VelodromeV2Router.Route[](1);
        routes[0] = VelodromeV2Router.Route({
            from : assetIn.token,
            to : assetOut.token,
            stable : abi.decode(extra, (bool)),
            factory : address(0)  // we can use address(0), defaultFactory will be used
        });
        uint256[] memory amounts = VelodromeV2Router(address(router)).getAmountsOut(amountIn, routes);
        amountOut = amounts[1];
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
        VelodromeV2Router.Route[] memory routes = new VelodromeV2Router.Route[](1);
        routes[0] = VelodromeV2Router.Route({
            from : tokenIn,
            to : tokenOut,
            stable : abi.decode(extra, (bool)),
            factory : address(0)  // we can use address(0), defaultFactory will be used
        });
        uint256[] memory amounts = VelodromeV2Router(address(router)).swapExactTokensForTokens(
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
        IUniswapV2Router02, //router
        IUniswapV2Pair pair,
        bool //isFromToken0
    ) internal pure virtual override returns (uint256) {
        IPoolFactory factory = IPoolFactory(VelodromeV2Pair(address(pair)).factory());
        return factory.getFee(address(pair), VelodromePair(address(pair)).stable());
    }
}
