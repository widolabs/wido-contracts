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

import "./WidoZapper_ERC20_ERC20.sol";
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

    function limitLower() external pure returns (int24);

    function limitUpper() external pure returns (int24);

    function withdraw(
        uint256 shares,
        address to,
        address from,
        uint256[4] memory minAmounts
    ) external returns (uint256 amount0, uint256 amount1);

    function getTotalAmounts() external view returns (uint256 total0, uint256 total1);

    function totalSupply() external view returns (uint256 total);
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
contract WidoZapperGammaAlgebra is WidoZapper_ERC20_ERC20 {
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

    struct Ratios {
        uint160 X96;
        uint160 AX96;
        uint160 BX96;
    }

    /// @inheritdoc WidoZapper_ERC20_ERC20
    function calcMinToAmountForZapIn(
        IUniswapV2Router02, //router,
        IUniswapV2Pair pair,
        address fromToken,
        uint256 amount,
        bytes calldata //extra
    ) external view virtual override returns (uint256 minToToken) {
        Hypervisor hyper = Hypervisor(address(pair));
        IAlgebraPool pool = IAlgebraPool(Hypervisor(address(pair)).pool());
        uint256 amount0;
        uint256 amount1;

        // we need the balanced amounts to compute the shares
        {
            (uint160 sqrtPriceX96,,,,,,) = pool.globalState();
            (amount0, amount1) = _balancedAmounts(
                address(pair),
                sqrtPriceX96,
                amount,
                pair.token0() == fromToken
            );
        }
        // Following is how Gamma computes the `shares` when you deposit.
        // shares is what we call liquidity here.
        // What they internally call liquidity is the amount of liquidity added on each tick
        //  but those two added don't equal to the shares

        (uint256 pool0, uint256 pool1) = hyper.getTotalAmounts();
        uint256 total = hyper.totalSupply();

        uint160 sqrtPrice = TickMath.getSqrtRatioAtTick(hyper.currentTick());
        uint256 price = FullMath.mulDiv(uint256(sqrtPrice).mul(uint256(sqrtPrice)), 1e36, 2**(96 * 2));

        uint256 shares = amount1.add(amount0.mul(price) / 1e36);

        uint256 pool0PricedInToken1 = pool0.mul(price) / 1e36;
        minToToken = shares.mul(total) / pool0PricedInToken1.add(pool1);
    }

    /// @inheritdoc WidoZapper_ERC20_ERC20
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

        (uint amount0, uint amount1) = _getAmountsOut(Hypervisor(address(pair)), amount);

        (uint160 sqrtRatioX96,,,,,,) = pool.globalState();
        uint256 token0Price = FullMath.mulDiv(sqrtRatioX96.mul(1e18), sqrtRatioX96, 2 ** 192);

        if (isZapToToken0) {
            minToToken = amount0 + (amount1 * 1e18) / token0Price;
        } else {
            minToToken = amount1 + (amount0 * token0Price) / 1e18;
        }
    }

    function _getAmountsOut(
        Hypervisor hyper,
        uint256 shares
    ) internal view returns (uint256 amount0, uint256 amount1) {
        (uint base0, uint base1) = _amountsForShares(hyper, hyper.baseLower(), hyper.baseUpper(), shares);
        (uint limit0, uint limit1) = _amountsForShares(hyper, hyper.limitLower(), hyper.limitUpper(), shares);
        uint256 unusedAmount0 = IERC20(hyper.token0()).balanceOf(address(hyper)).mul(shares) / hyper.totalSupply();
        uint256 unusedAmount1 = IERC20(hyper.token1()).balanceOf(address(hyper)).mul(shares) / hyper.totalSupply();
        amount0 = base0.add(limit0).add(unusedAmount0);
        amount1 = base1.add(limit1).add(unusedAmount1);
    }

    function _amountsForShares(
        Hypervisor hyper,
        int24 tickLower,
        int24 tickUpper,
        uint256 shares
    ) internal view returns (uint256, uint256) {
        IAlgebraPool pool = IAlgebraPool(hyper.pool());
        bytes32 positionKey = keccak256(abi.encodePacked(address(hyper), tickLower, tickUpper));
        (uint position, , , ,) = pool.positions(positionKey);
        uint128 liquidity = uint128(position.mul(shares) / hyper.totalSupply());
        (uint160 sqrtRatioX96, , , , , ,) = pool.globalState();
        return
        LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
    }

    /// @inheritdoc WidoZapper_ERC20_ERC20
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
    }

    /// @inheritdoc WidoZapper_ERC20_ERC20
    function _removeLiquidityAndSwap(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address toToken,
        bytes memory //extra
    ) internal virtual override returns (uint256) {
        address token0 = pair.token0();
        address token1 = pair.token1();
        require(token0 == toToken || token1 == toToken, "Desired token not present in liquidity pair");
        uint256[4] memory inMin;
        uint256 amount = IERC20(address(pair)).balanceOf(address(this));

        Hypervisor(address(pair)).withdraw(
            amount,
            address(this),
            address(this),
            inMin
        );

        address fromToken = token1 == toToken
        ? token0
        : token1;

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

        (uint256 amount0, uint256 amount1) = _balancedAmounts(
            zap.pool,
            zap.sqrtPriceX96,
            zap.amount,
            zap.fromToken0
        );

        /*
        Thoughts:

        - Gamma doesn't require the ticks to deposit
        - We need the ticks only to compute the correct balanced amounts
        - With `getDepositAmount` from `UniProxy` we can get the `amount of token to deposit for the given amount of pair token`
            - I understand that means `amount0 given amount1`
        - If that is the case we can use that function to get the ratio and balance amounts
*/

        // now we know how much of each token we need, so we can sell the difference
        //
        // The swap is not always going to be exact, so afterwards we check how much token we received,
        // and from that compute the amounts in the correct ratio.

        uint256 balanceOut;

        if (zap.fromToken0) {
            _swap(
                zap.router,
                zap.amount - amount0,
                zap.token0,
                zap.token1
            );
            // we are still relaying on this to get an accepted ratio
            // without this we get constant `Improper ratio`
            balanceOut = IERC20(zap.token1).balanceOf(address(this));
            // if we have less balance than we say, we need to fix the amounts
            if (balanceOut < amount1) {
                // set balance into amount
                amount1 = balanceOut;
                // compute correct ratio,
                // since we know we input less amount,
                // any amount this function returns should be bigger than our balance
                amount0 = _getPairAmount(zap.pool, zap.token1, amount1);
            }
            //
        }
        else {
            _swap(
                zap.router,
                zap.amount - amount1,
                zap.token1,
                zap.token0
            );
            // we are still relaying on this to get an accepted ratio
            // without this we get constant `Improper ratio`
            balanceOut = IERC20(zap.token0).balanceOf(address(this));
            if (balanceOut < amount0) {
                amount0 = balanceOut;
                amount1 = _getPairAmount(zap.pool, zap.token0, amount0);
            }
            //
        }

        // deposit liquidity into the pool

        //amount0 = IERC20(zap.token0).balanceOf(address(this));
        //amount1 = IERC20(zap.token1).balanceOf(address(this));

        _approveTokenIfNeeded(zap.token0, zap.pool, amount0);
        _approveTokenIfNeeded(zap.token1, zap.pool, amount1);
        (uint256[4] memory inMin) = abi.decode(zap.extra, (uint256[4]));

        liquidity = UniProxy(
            Hypervisor(zap.pool).whitelistedAddress()
        ).deposit(
            amount0,
            amount1,
            address(this),
            zap.pool,
            inMin
        );
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
        // get sample pair of amounts with correct ratio
        if (isZapFromToken0) {
            amount0 = 1e18;
            amount1 = _getPairAmount(pool, Hypervisor(pool).token0(), amount0);
        }
        else {
            amount1 = 1e18;
            amount0 = _getPairAmount(pool, Hypervisor(pool).token1(), amount1);
        }

        // compute optimal ratio

        uint256 token0Price = FullMath.mulDiv(uint256(sqrtPriceX96).mul(uint256(sqrtPriceX96)), 1e18, 2 ** (96 * 2));

        uint256 optimalRatio;
        if (amount0 == 0) {
            optimalRatio = amount * token0Price;
        } else {
            optimalRatio = (amount1 * 1e18) / amount0;
        }

        // compute `amount0` and `amount1` with correct ratio,
        //   that equal to `amount` in value,

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
