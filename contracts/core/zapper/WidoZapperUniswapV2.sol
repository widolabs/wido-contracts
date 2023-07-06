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
    using LowGasSafeMath for uint256;

    /// @dev This function checks that the pair belongs to the factory
    function _requires(IUniswapV2Router02 router, IUniswapV2Pair pair)
    internal virtual override {
        require(pair.factory() == router.factory(), "Incompatible router and pair");
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
    returns (uint256 liquidity) {
        (,, liquidity) = router.addLiquidity(
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
    function _balanceAssets(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address tokenA,
        address tokenB,
        bytes memory extra
    )
    internal virtual override
    returns (uint256[] memory amounts) {
        (uint256 reserveA, uint256 reserveB,) = pair.getReserves();
        uint256 fullInvestment = IERC20(tokenA).balanceOf(address(this));

        Asset memory assetFrom;
        Asset memory assetTo;

        if (pair.token0() == tokenA) {
            assetFrom = Asset(reserveA, tokenA);
            assetTo = Asset(reserveB, tokenB);
        } else {
            assetFrom = Asset(reserveB, tokenA);
            assetTo = Asset(reserveA, tokenB);
        }

        uint256 swapAmountIn = _getAmountBToSwap(
            router,
            fullInvestment,
            assetFrom,
            assetTo,
            extra
        );

        _approveTokenIfNeeded(tokenA, address(router));

        amounts = new uint256[](2);
        amounts[0] = fullInvestment - swapAmountIn;
        amounts[1] = _swap(
            router,
            swapAmountIn,
            tokenA,
            tokenB,
            extra
        );
    }

    function _getAmountBToSwap(
        IUniswapV2Router02 router,
        uint256 investmentA,
        Asset memory assetA,
        Asset memory assetB,
        bytes memory extra
    )
    internal pure
    returns (uint256 swapAmount) {
        uint256 halfInvestment = investmentA / 2;
        uint256 nominator = _getAmountOut(router, halfInvestment, assetA, assetB, extra);
        uint256 denominator = _quote(
            router,
            halfInvestment,
            assetA.reserves.add(halfInvestment),
            assetB.reserves.sub(nominator)
        );
        swapAmount = investmentA.sub(
            Babylonian.sqrt(
                (halfInvestment * halfInvestment * nominator) / denominator
            )
        );
    }

    /// @dev This function quotes the expected amountB given a certain amountA, while the pool has the specified reserves
    function _quote(IUniswapV2Router02 router, uint256 amountA, uint256 reserveA, uint256 reserveB)
    internal pure virtual
    returns (uint256 amountB) {
        return router.quote(amountA, reserveA, reserveB);
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
        return router.getAmountOut(amountIn, assetIn.reserves, assetOut.reserves);
    }

    /// @dev This function swap amountIn through the path
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
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            1,
            path,
            address(this),
            block.timestamp
        );
        amountOut = amounts[1];
    }
}
