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

import "./WidoZapperGammaAlgebra.sol";
import "../interfaces/IUniswapV3Pool.sol";
import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';

interface ISwapRouterRetro is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ISwapRouterRetro.ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @title Gamma pools Zapper
/// @notice Add or remove liquidity from Gamma pools using just one of the pool tokens
contract WidoZapperGammaRetro is WidoZapperGammaAlgebra {
    function _sqrtRatioX96(address _pool) internal view virtual override returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,,,,) = IUniswapV3Pool(_pool).slot0();
    }

    /// @dev This function swap amountIn through the path
    function _swap(
        address router,
        address pool,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    )
    internal virtual override
    returns (uint256 amountOut) {
        ISwapRouterRetro.ExactInputSingleParams memory params = ISwapRouterRetro.ExactInputSingleParams({
            tokenIn : tokenIn,
            tokenOut : tokenOut,
            fee: IUniswapV3Pool(Hypervisor(pool).pool()).fee(),
            recipient : address(this),
            deadline : block.timestamp,
            amountIn : amountIn,
            amountOutMinimum : 0,
            sqrtPriceLimitX96 : 0
        });
        _approveTokenIfNeeded(tokenIn, router, amountIn);
        amountOut = ISwapRouterRetro(router).exactInputSingle(params);
    }

}
