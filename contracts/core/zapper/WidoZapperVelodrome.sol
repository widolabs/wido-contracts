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
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface VelodromePair {
    function stable() external pure returns (bool);

    function token0() external pure returns (address);

    function token1() external pure returns (address);
}

interface VelodromePairFactory {
    function getFee(bool stable) external pure returns (uint256);

    function isPair(address pair) external view returns (bool);
}

interface VelodromeRouter {

    struct route {
        address from;
        address to;
        bool stable;
    }

    function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);

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

    /// @inheritdoc WidoZapperUniswapV2
    function _getAmountOut(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        uint256 amountIn,
        Asset memory assetIn,
        Asset memory assetOut,
        bytes memory //extra
    )
    internal view virtual override
    returns (uint256 amountOut) {
        VelodromePairFactory factory = VelodromePairFactory(VelodromeRouter(address(router)).factory());
        bool stable = VelodromePair(address(pair)).stable();
        uint reserve0;
        uint reserve1;

        if (VelodromePair(address(pair)).token0() == assetIn.token){
            reserve0 = assetIn.reserves;
            reserve1 = assetOut.reserves;
        }
        else {
            reserve0 = assetOut.reserves;
            reserve1 = assetIn.reserves;
        }

        // remove fee from amount received
        // we use the denominator used by Velodrome
        amountIn -= amountIn * factory.getFee(stable) / 10_000;

        return __getAmountOut(amountIn, assetIn.token, VelodromePair(address(pair)), reserve0, reserve1, stable);
    }

    // Code below is copied from Velodrome's Pair contract
    // https://github.com/velodrome-finance/v1/blob/de6b2a19b5174013112ad41f07cf98352bfe1f24/contracts/Pair.sol
    //
    // The reason to copy the logic into our contract is:
    // We want to get the estimated amountOut of a swap that will happen after a withdrawal,
    // if we use the function from Velodrome's contract, it uses the reserves existing prior withdraw.
    // The only way to estimate correctly is to bring the logic here and use the updated reserve values post withdrawal.

    function __getAmountOut(
        uint amountIn,
        address tokenIn,
        VelodromePair pair,
        uint _reserve0,
        uint _reserve1,
        bool stable
    ) private view returns (uint) {
        if (stable) {
            uint decimals0 = 10 ** IERC20Metadata(pair.token0()).decimals();
            uint decimals1 = 10 ** IERC20Metadata(pair.token1()).decimals();
            uint xy = _k(_reserve0, _reserve1, decimals0, decimals1, stable);
            _reserve0 = _reserve0 * 1e18 / decimals0;
            _reserve1 = _reserve1 * 1e18 / decimals1;
            (uint reserveA, uint reserveB) = tokenIn == pair.token0() ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
            amountIn = tokenIn == pair.token0() ? amountIn * 1e18 / decimals0 : amountIn * 1e18 / decimals1;
            uint y = reserveB - _get_y(amountIn + reserveA, xy, reserveB);
            return y * (tokenIn == pair.token0() ? decimals1 : decimals0) / 1e18;
        } else {
            (uint reserveA, uint reserveB) = tokenIn == pair.token0() ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
            return amountIn * reserveB / (reserveA + amountIn);
        }
    }

    function _k(uint x, uint y, uint decimals0, uint decimals1, bool stable) internal pure returns (uint) {
        if (stable) {
            uint _x = x * 1e18 / decimals0;
            uint _y = y * 1e18 / decimals1;
            uint _a = (_x * _y) / 1e18;
            uint _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
            return _a * _b / 1e18;
            // x3y+y3x >= k
        } else {
            return x * y;
            // xy >= k
        }
    }

    function _get_y(uint x0, uint xy, uint y) internal pure returns (uint) {
        for (uint i = 0; i < 255; i++) {
            uint y_prev = y;
            uint k = _f(x0, y);
            if (k < xy) {
                uint dy = (xy - k) * 1e18 / _d(x0, y);
                y = y + dy;
            } else {
                uint dy = (k - xy) * 1e18 / _d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

    function _d(uint x0, uint y) internal pure returns (uint) {
        return 3 * x0 * (y * y / 1e18) / 1e18 + (x0 * x0 / 1e18 * x0 / 1e18);
    }

    function _f(uint x0, uint y) internal pure returns (uint) {
        return x0*(y*y/1e18*y/1e18)/1e18+(x0*x0/1e18*x0/1e18)*y/1e18;
    }
}
