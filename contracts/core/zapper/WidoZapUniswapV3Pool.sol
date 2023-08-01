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

pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

/// @title Uniswap V3 pools Zap
/// @author Wido
/// @notice Add or remove liquidity from Uniswap V3 pools using just one of the pool tokens
contract WidoZapUniswapV3Pool is IERC721Receiver {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for uint160;
    using SafeERC20 for IERC20;

    /// @param fromToken Address of the token to swap
    /// @param amount Amount of the from token to spend on the user's behalf
    /// @param minToToken Minimum amount of the pool token the user is willing to accept
    /// @param pool Address of the pool contract to add liquidity into
    struct ZapInOrder {
        IUniswapV3Pool pool;
        address fromToken;
        uint256 amount;
        int24 lowerTick;
        int24 upperTick;
        uint256 minToToken;
    }

    /// @param fromToken Address of the token to swap
    /// @param amount Amount of the from token to spend on the user's behalf
    /// @param minToToken Minimum amount of the pool token the user is willing to accept
    /// @param pool Address of the pool contract to add liquidity into
    struct ZapOutOrder {
        IUniswapV3Pool pool;
        address toToken;
        uint256 minToToken;
        uint256 tokenId;
    }

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @notice Add liquidity to an Uniswap V3 pool using one of the pool tokens
    /// @param router Address of the UniswapV3's SwapRouter02 contract
    function zapIn(
        ISwapRouter02 router,
        INonfungiblePositionManager nonfungiblePositionManager,
        ZapInOrder memory order
    ) external {
        // require(order.pool.factory() == router.factory(), "Incompatible router and pool");
        require(
            order.pool.factory() == nonfungiblePositionManager.factory(),
            "Incompatible nonfungiblePositionManager and pool"
        );

        IERC20(order.fromToken).safeTransferFrom(msg.sender, address(this), order.amount);

        address token0 = order.pool.token0();
        address token1 = order.pool.token1();

        bool isZapFromToken0 = token0 == order.fromToken;
        require(isZapFromToken0 || token1 == order.fromToken, "Input token not present in liquidity pool");

        (uint256 amount0, uint256 amount1, , , , uint256 token0Price) = _calcZapInAmounts(
            order.pool,
            order.amount,
            order.lowerTick,
            order.upperTick,
            isZapFromToken0
        );

        if (isZapFromToken0) {
            if (order.amount - amount0 > 0) {
                _swap(router, order.pool, order.fromToken, token1, order.amount - amount0);
            }
        } else {
            if (order.amount - amount1 > 0) {
                _swap(router, order.pool, order.fromToken, token0, order.amount - amount1);
            }
        }

        amount0 = IERC20(token0).balanceOf(address(this));
        amount1 = IERC20(token1).balanceOf(address(this));

        (uint256 tokenId, uint128 liquidity) = _addLiquidity(
            nonfungiblePositionManager,
            order,
            token0,
            token1,
            amount0,
            amount1
        );

        uint256 dustBalance = IERC20(token0).balanceOf(address(this));
        if (dustBalance * token0Price > 1e18) {
            (amount0, amount1, , , , ) = _calcZapInAmounts(
                order.pool,
                dustBalance,
                order.lowerTick,
                order.upperTick,
                true
            );
            _swap(router, order.pool, token0, token1, dustBalance - amount0);

            INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: IERC20(token0).balanceOf(address(this)),
                    amount1Desired: IERC20(token1).balanceOf(address(this)),
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });
            (uint128 addedLiquidity, , ) = nonfungiblePositionManager.increaseLiquidity(params);
            liquidity += addedLiquidity;
        }

        dustBalance = IERC20(token1).balanceOf(address(this));
        if ((dustBalance * 1e18) / token0Price > 0) {
            (amount0, amount1, , , , ) = _calcZapInAmounts(
                order.pool,
                dustBalance,
                order.lowerTick,
                order.upperTick,
                false
            );
            _swap(router, order.pool, token1, token0, dustBalance - amount1);

            INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: IERC20(token0).balanceOf(address(this)),
                    amount1Desired: IERC20(token1).balanceOf(address(this)),
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });
            (uint128 addedLiquidity, , ) = nonfungiblePositionManager.increaseLiquidity(params);
            liquidity += addedLiquidity;
        }

        require(liquidity >= order.minToToken, "Slippage too high");

        nonfungiblePositionManager.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    /// @notice Remove liquidity from an Uniswap V3 pool into one of the pool tokens
    /// @param router Address of the UniswapV3's SwapRouter02 contract
    function zapOut(
        ISwapRouter02 router,
        INonfungiblePositionManager nonfungiblePositionManager,
        ZapOutOrder memory order
    ) external {
        require(
            order.pool.factory() == nonfungiblePositionManager.factory(),
            "Incompatible nonfungiblePositionManager and pool"
        );

        address token0 = order.pool.token0();
        address token1 = order.pool.token1();

        nonfungiblePositionManager.safeTransferFrom(msg.sender, address(this), order.tokenId);

        bool isZapToToken0 = token0 == order.toToken;
        require(isZapToToken0 || token1 == order.toToken, "Output token not present in liquidity pool");

        (uint256 amount0, uint256 amount1) = _removeLiquidity(nonfungiblePositionManager, order);

        if (isZapToToken0) {
            if (amount1 > 0) {
                _swap(router, order.pool, token1, order.toToken, amount1);
            }
        } else {
            if (amount0 > 0) {
                _swap(router, order.pool, token0, order.toToken, amount0);
            }
        }

        uint256 toTokenAmount = IERC20(order.toToken).balanceOf(address(this));

        require(toTokenAmount >= order.minToToken, "Slippage too high");

        IERC20(order.toToken).safeTransfer(msg.sender, toTokenAmount);
    }

    function _removeLiquidity(INonfungiblePositionManager nonfungiblePositionManager, ZapOutOrder memory order)
        private
        returns (uint256 amount0, uint256 amount1)
    {
        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager.positions(order.tokenId);
        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager
            .DecreaseLiquidityParams({
                tokenId: order.tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
        nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: order.tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        nonfungiblePositionManager.burn(order.tokenId);
    }

    function _swap(
        ISwapRouter02 router,
        IUniswapV3Pool pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private {
        _approveTokenIfNeeded(tokenIn, address(router));
        ISwapRouter02(router).exactInputSingle(
            IV3SwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: pool.fee(),
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0,
                recipient: address(this)
            })
        );
    }

    function _addLiquidity(
        INonfungiblePositionManager nonfungiblePositionManager,
        ZapInOrder memory order,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) private returns (uint256 tokenId, uint128 liquidity) {
        _approveTokenIfNeeded(token0, address(nonfungiblePositionManager));
        _approveTokenIfNeeded(token1, address(nonfungiblePositionManager));
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: order.pool.fee(),
            tickLower: order.lowerTick,
            tickUpper: order.upperTick,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });

        (tokenId, liquidity, , ) = nonfungiblePositionManager.mint(params);
    }

    function _calcZapInAmounts(
        IUniswapV3Pool pool,
        uint256 amount,
        int24 lowerTick,
        int24 upperTick,
        bool isZapFromToken0
    )
        private
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint160 sqrtPriceX96,
            uint160 sqrtRatioAX96,
            uint160 sqrtRatioBX96,
            uint256 token0Price
        )
    {
        (sqrtPriceX96, , , , , , ) = pool.slot0();
        token0Price = FullMath.mulDiv(sqrtPriceX96.mul(1e18), sqrtPriceX96, 2**192);
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

    function _approveTokenIfNeeded(address token, address spender) private {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    /// @notice Calculate the amount of pool tokens received when adding liquidity to an UniswapV3 pool using a single asset.
    /// @param pool Address of the pool contract to add liquidity into
    /// @param fromToken Address of the from token
    /// @param amount Amount of the from token
    /// @return minToToken Minimum amount of the lp token the user would receive in a no-slippage scenario.
    function calcMinToAmountForZapIn(
        IUniswapV3Pool pool,
        address fromToken,
        uint256 amount,
        int24 lowerTick,
        int24 upperTick
    ) external view returns (uint128 minToToken) {
        bool isZapFromToken0 = pool.token0() == fromToken;
        require(isZapFromToken0 || pool.token1() == fromToken, "Input token not present in liquidity pool");

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

    /// @notice Calculate the amount of to tokens received when removing liquidity from an UniswapV3 pool into a single asset.
    /// @param pool Address of the pool contract to add liquidity into
    /// @param toToken Address of the to token
    /// @param liquidity Amount of liquidity
    /// @return minToToken Minimum amount of the to token the user would receive in a no-slippage scenario.
    function calcMinToAmountForZapOut(
        IUniswapV3Pool pool,
        address toToken,
        uint128 liquidity,
        int24 lowerTick,
        int24 upperTick
    ) external view returns (uint256 minToToken) {
        bool isZapToToken0 = pool.token0() == toToken;
        require(isZapToToken0 || pool.token1() == toToken, "Output token not present in liquidity pool");

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(upperTick);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            liquidity
        );
        uint256 token0Price = FullMath.mulDiv(sqrtPriceX96.mul(1e18), sqrtPriceX96, 2**192);

        if (isZapToToken0) {
            minToToken = amount0 + (amount1 * 1e18) / token0Price;
        } else {
            minToToken = amount1 + (amount0 * token0Price) / 1e18;
        }
    }
}
