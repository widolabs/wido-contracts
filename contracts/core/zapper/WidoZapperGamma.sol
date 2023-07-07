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

import "./WidoZapper.sol";
import "@cryptoalgebra/periphery/contracts/interfaces/ISwapRouter.sol";
import "@cryptoalgebra/core/contracts/libraries/TickMath.sol";
import "@cryptoalgebra/periphery/contracts/libraries/LiquidityAmounts.sol";
import "@cryptoalgebra/core/contracts/interfaces/IAlgebraPool.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface Hypervisor {
    function whitelistedAddress() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function pool() external pure returns (address);

    function currentTick() external pure returns (int24);

    function baseLower() external pure returns (int24);

    function baseUpper() external pure returns (int24);
}

interface UniProxy {
    function deposit(uint256 deposit0, uint256 deposit1, address to, address pos, uint256[4] memory minIn) external returns (uint256);

    function getDepositAmount(
        address pos,
        address token,
        uint256 _deposit
    ) external view returns (uint256 amountStart, uint256 amountEnd);
}

/// @title Gamma pools Zapper
/// @notice Add or remove liquidity from Gamma pools using just one of the pool tokens
contract WidoZapperGamma is WidoZapper {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for uint160;
    using SafeERC20 for IERC20;

    /// @dev there's a point at which the gas cost doesn't compensate the dust value
    uint256 immutable public DUST_THRESHOLD = 1e10;

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

    /// @inheritdoc WidoZapper
    function calcMinToAmountForZapIn(
        IUniswapV2Router02, //router,
        IUniswapV2Pair pair,
        address fromToken,
        uint256 amount,
        bytes calldata //extra
    ) external view virtual override returns (uint256 minToToken) {
        IAlgebraPool pool = IAlgebraPool(Hypervisor(address(pair)).pool());
        bool isZapFromToken0 = pool.token0() == fromToken;
        (uint160 sqrtPriceX96,,,,,,) = pool.globalState();

        (uint256 amount0, uint256 amount1) = _balancedAmounts(address(pair), sqrtPriceX96, amount, isZapFromToken0);

        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(Hypervisor(address(pair)).baseLower());
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(Hypervisor(address(pair)).baseUpper());

        minToToken = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            amount0,
            amount1
        );
    }

    /// @inheritdoc WidoZapper
    function calcMinToAmountForZapOut(
        IUniswapV2Router02, // router,
        IUniswapV2Pair pair,
        address toToken,
        uint256 amount,
        bytes calldata //extra
    ) external view virtual override returns (uint256 minToToken) {
        IAlgebraPool pool = IAlgebraPool(Hypervisor(address(pair)).pool());

        bool isZapToToken0 = pool.token0() == toToken;
        require(isZapToToken0 || pool.token1() == toToken, "Output token not present in liquidity pool");

        (uint160 sqrtPriceX96,,,,,,) = pool.globalState();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(Hypervisor(address(pair)).baseLower());
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(Hypervisor(address(pair)).baseUpper());

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            uint128(amount)
        );
        uint256 token0Price = FullMath.mulDiv(sqrtPriceX96 * 1e18, sqrtPriceX96, 2 ** 192);

        if (isZapToToken0) {
            minToToken = amount0 + (amount1 * 1e18) / token0Price;
        } else {
            minToToken = amount1 + (amount0 * token0Price) / 1e18;
        }
    }

    /// @inheritdoc WidoZapper
    function _swapAndAddLiquidity(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address tokenA,
        bytes memory extra
    ) internal override returns (uint256 liquidity) {
        IAlgebraPool pool = IAlgebraPool(Hypervisor(address(pair)).pool());
        (uint160 sqrtPriceX96,,,,,,) = pool.globalState();
        uint256 amount = IERC20(tokenA).balanceOf(address(this));
        bool fromToken0 = pool.token0() == tokenA;

        Zap memory zap = Zap(
            address(router),
            address(pair),
            pool.token0(),
            pool.token1(),
            sqrtPriceX96,
            amount,
            fromToken0,
            extra
        );

        liquidity = _deposit(zap);

        liquidity = liquidity + _liquidateDust(zap);
    }

    /// @inheritdoc WidoZapper
    function _removeLiquidityAndSwap(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address toToken,
        bytes memory extra
    ) internal virtual override returns (uint256) {
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

        (address swapRouter,) = abi.decode(extra, (address, uint256[4]));

        _swap(
            address(router),
            IERC20(fromToken).balanceOf(address(this)),
            fromToken,
            toToken
        );

        return IERC20(toToken).balanceOf(address(this));
    }

    /// @notice Re-balances `amount` of the input token, and deposits into the pool
    /// @return liquidity Amount of added liquidity into the vault
    function _deposit(Zap memory zap) private returns (uint256 liquidity) {

        // first we compute the ideal token balances that we should try to deposit,
        //  given the value of our input assets

        // obtain `amount0` and `amount1` that equal to `amount` of the given token
        (uint256 amount0, uint256 amount1) = _balancedAmounts(
            zap.pool,
            zap.sqrtPriceX96,
            zap.amount,
            zap.fromToken0
        );

        // now we know how much of each token we need, so we can sell the difference
        //  on what we have.
        // The swap is not always going to be exact, so afterwards we check how much
        //  token we received, and from that compute the pair amount in ratio.

        // swap excess amount of input token for the pair token
        uint256 balanceOut;

        if (zap.fromToken0) {
            _swap(
                zap.router,
                zap.amount - amount0,
                zap.token0,
                zap.token1
            );
            balanceOut = IERC20(zap.token1).balanceOf(address(this));
            if (balanceOut < amount1) {
                amount1 = balanceOut;
                amount0 = _getPairAmount(zap.pool, zap.token1, amount1);
            }
        }
        else {
            _swap(
                zap.router,
                zap.amount - amount1,
                zap.token1,
                zap.token0
            );
            balanceOut = IERC20(zap.token0).balanceOf(address(this));
            if (balanceOut < amount0) {
                amount0 = balanceOut;
                amount1 = _getPairAmount(zap.pool, zap.token0, amount0);
            }
        }

        // pegging the amounts like this will generally leave some dust
        //  so we'll have to run this function more than once

        // deposit liquidity into the pool

        _approveTokenIfNeeded(zap.token0, zap.pool, amount0);
        _approveTokenIfNeeded(zap.token1, zap.pool, amount1);
        (uint256[4] memory inMin) = abi.decode(zap.extra, (uint256[4]));

        liquidity = UniProxy(
            Hypervisor(zap.pool).whitelistedAddress()
        ).deposit(
            amount0,
            amount1,
            msg.sender,
            zap.pool,
            inMin
        );
    }

    /// @dev This will iterate and deposit remaining amount of any token
    function _liquidateDust(Zap memory zap) internal returns (uint256 liquidity) {
        // check token0 dust
        uint8 _decimals = IERC20Metadata(zap.token0).decimals();
        zap.amount = IERC20(zap.token0).balanceOf(address(this));
        zap.fromToken0 = true;
        while (zap.amount > 10 ** (_decimals / 2)) {
            // re-balance and deposit
            liquidity = liquidity + _deposit(zap);
            // check remaining dust
            zap.amount = IERC20(zap.token0).balanceOf(address(this));
        }

        // check token1 dust
        _decimals = IERC20Metadata(zap.token0).decimals();
        zap.amount = IERC20(zap.token1).balanceOf(address(this));
        zap.fromToken0 = false;
        while (zap.amount > 10 ** (_decimals / 2)) {
            // re-balance and deposit
            liquidity = liquidity + _deposit(zap);
            // check remaining dust
            zap.amount = IERC20(zap.token1).balanceOf(address(this));
        }
    }

    /// @dev This function swap amountIn through the path
    function _swap(
        address router,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    )
    internal virtual
    returns (uint256 amountOut) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn : tokenIn,
            tokenOut : tokenOut,
            recipient : address(this),
            deadline : block.timestamp,
            amountIn : amountIn,
            amountOutMinimum : 0,
            limitSqrtPrice : 0
        });
        _approveTokenIfNeeded(tokenIn, router, amountIn);
        amountOut = ISwapRouter(router).exactInputSingle(params);
    }

    /// @notice Computes the amount of the opposite asset that should be deposited to be a balanced deposit
    /// @param pool Address of the Hypervisor vault
    /// @param token Token address of the specified amount
    /// @param amount Amount of assets we know we want to input
    /// @return pairAmount Amount of the opposite token that needs to balance the position
    function _getPairAmount(address pool, address token, uint256 amount) private view returns (uint256 pairAmount) {
        (uint256 start, uint256 end) = UniProxy(
            Hypervisor(pool).whitelistedAddress()
        ).getDepositAmount(
            pool,
            token,
            amount
        );
        pairAmount = start + ((end - start) / 2);
    }

    /// @notice Computes `amount0` and `amount1` that equal to the `amount` of the given token
    function _balancedAmounts(
        address pool,
        uint160 sqrtPriceX96,
        uint256 amount,
        bool isZapFromToken0
    )
    private view
    returns (
        uint256 amount0,
        uint256 amount1
    ) {
        if (isZapFromToken0) {
            amount0 = amount;
            amount1 = _getPairAmount(pool, Hypervisor(pool).token0(), amount);
        }
        else {
            amount1 = amount;
            amount0 = _getPairAmount(pool, Hypervisor(pool).token1(), amount);
        }

        uint256 token0Price = FullMath.mulDiv(uint256(sqrtPriceX96).mul(uint256(sqrtPriceX96)), 1e18, 2 ** (96 * 2));

        uint256 optimalRatio;
        if (amount0 == 0) {
            optimalRatio = amount * token0Price;
        } else {
            optimalRatio = (amount1 * 1e18) / amount0;
        }

        if (isZapFromToken0) {
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
