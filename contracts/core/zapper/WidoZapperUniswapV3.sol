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

pragma solidity ^0.8.7;

import "./WidoZapper_ERC20_ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@cryptoalgebra/periphery/contracts/libraries/LiquidityAmounts.sol";
import "@cryptoalgebra/core/contracts/libraries/TickMath.sol";

/// @title Gamma pools Zapper
/// @notice Add or remove liquidity from Gamma pools using just one of the pool tokens
contract WidoZapperUniswapV3 is WidoZapper_ERC20_ERC721 {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for uint160;
    using SafeERC20 for IERC20;

    struct Zap {
        address router;
        address pool;
        address token0;
        address token1;
        uint160 sqrtPriceX96;
        uint256 amount;
        bool fromToken0;
        bytes extra;
    }

    /// @inheritdoc WidoZapper_ERC20_ERC721
    function calcMinToAmountForZapIn(
        ISwapRouter02, // router
        IUniswapV3Pool pool,
        INonfungiblePositionManager, // positionManager
        address fromToken,
        uint256 amount,
        bytes calldata extra
    ) external view virtual override returns (uint256 minToToken) {
        bool isZapFromToken0 = pool.token0() == fromToken;
        require(isZapFromToken0 || pool.token1() == fromToken, "Input token not present in liquidity pool");

        (int24 lowerTick,int24 upperTick) = abi.decode(extra, (int24, int24));

        (
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtPriceX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,

        ) = _calcZapInAmounts(pool, amount, lowerTick, upperTick, isZapFromToken0);

        minToToken = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            amount0,
            amount1
        );
    }

    /// @inheritdoc WidoZapper_ERC20_ERC721
    function calcMinToAmountForZapOut(
        ISwapRouter02, //router
        IUniswapV3Pool pool,
        INonfungiblePositionManager, //positionManager
        address toToken,
        uint256 amount,
        bytes calldata extra
    ) external view virtual override returns (uint256 minToToken) {
        bool isZapToToken0 = pool.token0() == toToken;
        require(isZapToToken0 || pool.token1() == toToken, "Output token not present in liquidity pool");

        uint160 sqrtRatioAX96;
        uint160 sqrtRatioBX96;
        (uint160 sqrtPriceX96, , , , , ,) = pool.slot0();
        {
            (int24 lowerTick,int24 upperTick) = abi.decode(extra, (int24, int24));
            sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(lowerTick);
            sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(upperTick);
        }

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            uint128(amount)
        );
        uint256 token0Price = FullMath.mulDiv(sqrtPriceX96.mul(1e18), sqrtPriceX96, 2 ** 192);

        if (isZapToToken0) {
            minToToken = amount0 + (amount1 * 1e18) / token0Price;
        } else {
            minToToken = amount1 + (amount0 * token0Price) / 1e18;
        }
    }

    /// @inheritdoc WidoZapper_ERC20_ERC721
    function _swapAndAddLiquidity(
        ISwapRouter02 router,
        IUniswapV3Pool pool,
        INonfungiblePositionManager positionManager,
        address fromToken,
        uint256 amount,
        bytes memory extra
    ) internal override returns (uint256 liquidity, uint256 tokenId) {
        bool isZapFromToken0;
        {
            isZapFromToken0 = pool.token0() == fromToken;
            require(isZapFromToken0 || pool.token1() == fromToken, "Input token not present in liquidity pool");
        }
        uint256 amount0;
        uint256 amount1;
        {
            (int24 lowerTick,int24 upperTick) = abi.decode(extra, (int24, int24));
            (amount0, amount1,,,,) = _calcZapInAmounts(
                pool,
                amount,
                lowerTick,
                upperTick,
                isZapFromToken0
            );
        }

        if (isZapFromToken0) {
            if (amount - amount0 > 0) {
                _swap(router, pool, amount - amount0, fromToken, pool.token1());
            }
        } else {
            if (amount - amount1 > 0) {
                _swap(router, pool, amount - amount1, fromToken, pool.token0());
            }
        }

        {
            amount0 = IERC20(pool.token0()).balanceOf(address(this));
            amount1 = IERC20(pool.token1()).balanceOf(address(this));

            _approveTokenIfNeeded(pool.token0(), address(positionManager), amount0);
            _approveTokenIfNeeded(pool.token1(), address(positionManager), amount1);
        }

        (int24 lowerTick,int24 upperTick) = abi.decode(extra, (int24, int24));
        (tokenId, liquidity,,) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0 : pool.token0(),
                token1 : pool.token1(),
                fee : pool.fee(),
                tickLower : lowerTick,
                tickUpper : upperTick,
                amount0Desired : amount0,
                amount1Desired : amount1,
                amount0Min : 0,
                amount1Min : 0,
                recipient : address(this),
                deadline : block.timestamp
            })
        );
    }

    /// @inheritdoc WidoZapper_ERC20_ERC721
    function _removeLiquidityAndSwap(
        ISwapRouter02 router,
        IUniswapV3Pool pool,
        INonfungiblePositionManager positionManager,
        address toToken,
        uint256 tokenId,
        bytes memory //extra
    ) internal virtual override returns (uint256) {
        require(
            pool.factory() == positionManager.factory(),
            "Incompatible positionManager and pool"
        );

        bool isZapToToken0 = pool.token0() == toToken;
        require(isZapToToken0 || pool.token1() == toToken, "Output token not present in liquidity pool");

        (, , , , , , , uint128 liquidity, , , , ) = positionManager.positions(tokenId);

        (uint256 amount0, uint256 amount1) = positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        positionManager.burn(tokenId);

        if (isZapToToken0) {
            if (amount1 > 0) {
                _swap(router, pool, amount1, toToken, pool.token1());
            }
        } else {
            if (amount0 > 0) {
                _swap(router, pool, amount0, toToken, pool.token0());
            }
        }

        return IERC20(toToken).balanceOf(address(this));
    }

    /// @dev This function swap amountIn through the path
    function _swap(
        ISwapRouter02 router,
        IUniswapV3Pool pool,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    )
    internal virtual {
        _approveTokenIfNeeded(tokenIn, address(router), amountIn);
        router.exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn : tokenIn,
                tokenOut : tokenOut,
                fee : pool.fee(),
                amountIn : amountIn,
                amountOutMinimum : 0,
                sqrtPriceLimitX96 : 0,
                recipient : address(this)
            })
        );
    }

    function _calcZapInAmounts(
        IUniswapV3Pool pool,
        uint256 amount,
        int24 lowerTick,
        int24 upperTick,
        bool isZapFromToken0
    )
    private view
    returns (
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtPriceX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 token0Price
    )
    {
        (sqrtPriceX96,,,,,,) = pool.slot0();
        token0Price = FullMath.mulDiv(sqrtPriceX96.mul(1e18), sqrtPriceX96, 2 ** 192);
        sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(lowerTick);
        sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(upperTick);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, 1e18);

        uint256 optimalRatio;
        if (amount0 == 0) {
            optimalRatio = amount * token0Price;
        } else {
            optimalRatio = (amount1 * 1e18) / amount0;
        }

        if (isZapFromToken0) {
            // Todo use safemath
            amount0 = (amount * token0Price) / (optimalRatio + token0Price);
            amount1 = ((amount - amount0) * token0Price) / 1e18;
        } else {
            amount0 = (amount * 1e18) / (optimalRatio + token0Price);
            if (optimalRatio == 0) {
                amount1 = 0;
            } else {
                amount1 = amount - ((amount0 * token0Price) / 1e18);
            }
        }
    }
}
