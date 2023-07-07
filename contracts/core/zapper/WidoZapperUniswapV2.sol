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
    using SafeERC20 for IERC20;

    /// @notice Calculate the amount of pool tokens received when adding liquidity to an UniswapV2 pool using a single asset
    /// @param router Address of the UniswapV2Router02 contract
    /// @param pair Address of the pair contract to add liquidity into
    /// @param fromToken Address of the from token
    /// @param amount Amount of the from token
    /// @return minToToken Minimum amount of the lp token the user would receive in a no-slippage scenario.
    function calcMinToAmountForZapIn(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address fromToken,
        uint256 amount,
        bytes calldata extra
    )
    external view virtual override
    returns (uint256 minToToken) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        Asset memory asset0 = Asset(reserve0, pair.token0());
        Asset memory asset1 = Asset(reserve1, pair.token1());

        // checking initial balance into `amount`, will be reusing the slot
        uint256 amount0 = IERC20(asset0.token).balanceOf(address(pair));
        uint256 amount1 = IERC20(asset1.token).balanceOf(address(pair));

        require(asset0.token == fromToken || asset1.token == fromToken, "Input token not present in liquidity pair");

        uint256 halfAmount0;
        uint256 halfAmount1;

        // stack too deep, so we can't store this bool
        if (asset0.token == fromToken) {
            halfAmount0 = amount / 2;
            halfAmount1 = _getAmountOut(router, halfAmount0, asset0, asset1, extra);
        } else {
            halfAmount1 = amount / 2;
            halfAmount0 = _getAmountOut(router, halfAmount1, asset1, asset0, extra);
        }

        amount0 = amount0 + halfAmount0 - reserve0;
        amount1 = amount1 + halfAmount1 - reserve1;

        uint256 lpTotalSupply = pair.totalSupply();
        return Math.min(amount0.mul(lpTotalSupply) / reserve0, amount1.mul(lpTotalSupply) / reserve1);
    }

    /// @notice Calculate the amount of to tokens received when removing liquidity from an UniswapV2 pool into a single asset.
    /// @param router Address of the UniswapV2Router02 contract
    /// @param pair Address of the pair contract to remove liquidity from
    /// @param toToken Address of the to token
    /// @param lpAmount Amount of the lp token
    /// @return minToToken Minimum amount of the to token the user would receive in a no-slippage scenario.
    function calcMinToAmountForZapOut(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address toToken,
        uint256 lpAmount,
        bytes calldata extra
    )
    external view virtual override
    returns (uint256 minToToken) {
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        uint256 lpTotalSupply = pair.totalSupply();

        bool isZapToToken0 = pair.token0() == toToken;
        require(isZapToToken0 || pair.token1() == toToken, "Input token not present in liquidity pair");

        uint256 amount0;
        uint256 amount1;
        Asset memory asset0 = Asset(reserve0, pair.token0());
        Asset memory asset1 = Asset(reserve1, pair.token1());

        if (isZapToToken0) {
            amount0 = (lpAmount * reserve0) / lpTotalSupply;
            amount1 = _getAmountOut(
                router,
                (lpAmount * reserve1) / lpTotalSupply,
                asset1, asset0,
                extra
            );
        } else {
            amount0 = _getAmountOut(
                router,
                (lpAmount * reserve0) / lpTotalSupply,
                asset0, asset1,
                extra
            );
            amount1 = (lpAmount * reserve1) / lpTotalSupply;
        }

        return amount0 + amount1;
    }

    /// @notice Re-balances the amounts and adds liquidity to the pool
    function _swapAndAddLiquidity(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address tokenA,
        bytes memory extra
    )
    internal virtual override
    returns (uint256) {
        _requires(router, pair);

        bool isInputA = pair.token0() == tokenA;
        require(isInputA || pair.token1() == tokenA, "Input token not present in liquidity pair");

        address tokenB = isInputA
        ? pair.token1()
        : pair.token0();

        uint256[] memory balancedAmounts = _balanceAssets(router, pair, tokenA, tokenB, extra);

        _approveTokenIfNeeded(tokenA, address(router), balancedAmounts[0]);
        _approveTokenIfNeeded(tokenB, address(router), balancedAmounts[1]);

        uint256 poolTokenAmount = _addLiquidity(
            router,
            tokenA,
            tokenB,
            balancedAmounts[0],
            balancedAmounts[1],
            extra
        );

        return poolTokenAmount;
    }

    /// @notice Removes liquidity from the pool and converts everything to a single asset
    function _removeLiquidityAndSwap(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address toToken,
        bytes memory extra
    )
    internal virtual override
    returns (uint256) {
        _requires(router, pair);

        address token0 = pair.token0();
        address token1 = pair.token1();
        require(token0 == toToken || token1 == toToken, "Desired token not present in liquidity pair");

        IERC20(address(pair)).safeTransfer(
            address(pair),
            IERC20(address(pair)).balanceOf(address(this))
        );
        pair.burn(address(this));

        address fromToken = token1 == toToken
        ? token0
        : token1;

        _approveTokenIfNeeded(fromToken, address(router), IERC20(fromToken).balanceOf(address(this)));
        _swap(
            router,
            IERC20(fromToken).balanceOf(address(this)),
            fromToken,
            toToken,
            extra
        );

        return IERC20(toToken).balanceOf(address(this));
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
    internal virtual
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

    /// @notice This function swap amountIn through the path
    /// @param tokenA Input asset given by the user
    /// @param tokenB The pair token of the pool
    /// @param extra Bytes for extra details
    /// @return amounts Represent the position with the balanced amounts of tokens
    function _balanceAssets(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address tokenA,
        address tokenB,
        bytes memory extra
    )
    internal virtual
    returns (uint256[] memory amounts) {
        (uint256 reserveA, uint256 reserveB,) = pair.getReserves();
        uint256 fullInvestment = IERC20(tokenA).balanceOf(address(this));

        Asset memory assetFrom;
        Asset memory assetTo;

        // define direction of swap
        if (pair.token0() == tokenA) {
            assetFrom = Asset(reserveA, tokenA);
            assetTo = Asset(reserveB, tokenB);
        } else {
            assetFrom = Asset(reserveB, tokenA);
            assetTo = Asset(reserveA, tokenB);
        }

        // get amount of input token to be swapped
        uint256 swapAmountIn = _getAmountToSwap(
            router,
            fullInvestment,
            assetFrom,
            assetTo,
            extra
        );

        _approveTokenIfNeeded(tokenA, address(router), swapAmountIn);

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

    /// @notice Computes the amount of input tokens to swap to get a balanced position
    function _getAmountToSwap(
        IUniswapV2Router02 router,
        uint256 amountIn,
        Asset memory assetA,
        Asset memory assetB,
        bytes memory extra
    )
    internal pure
    returns (uint256 swapAmount) {
        uint256 halfInvestment = amountIn / 2;
        uint256 nominator = _getAmountOut(router, halfInvestment, assetA, assetB, extra);
        uint256 denominator = _quote(
            router,
            halfInvestment,
            assetA.reserves.add(halfInvestment),
            assetB.reserves.sub(nominator)
        );
        swapAmount = amountIn.sub(
            Babylonian.sqrt(
                (halfInvestment * halfInvestment * nominator) / denominator
            )
        );
    }

    /// @dev Checks that the pair belongs to the factory
    function _requires(IUniswapV2Router02 router, IUniswapV2Pair pair) internal virtual {
        require(pair.factory() == router.factory(), "Incompatible router and pair");
    }

    /// @dev Quotes the expected amountB given a certain amountA, while the pool has the specified reserves
    function _quote(IUniswapV2Router02 router, uint256 amountA, uint256 reserveA, uint256 reserveB)
    internal pure virtual
    returns (uint256 amountB) {
        return router.quote(amountA, reserveA, reserveB);
    }

    /// @dev Computes the amount out for a certain amount in
    function _getAmountOut(
        IUniswapV2Router02 router,
        uint256 amountIn,
        Asset memory assetIn,
        Asset memory assetOut,
        bytes memory //extra
    )
    internal pure virtual
    returns (uint256 amountOut) {
        return router.getAmountOut(amountIn, assetIn.reserves, assetOut.reserves);
    }

    /// @dev Swaps tokenIn into tokenB
    function _swap(
        IUniswapV2Router02 router,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        bytes memory //extra
    )
    internal virtual
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
