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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";
import "../interfaces/INonfungiblePositionManager.sol";
import "../interfaces/ISwapRouter02.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "../interfaces/IERC721Receiver.sol";

/// @notice Add or remove liquidity from Uniswap V2-like pools using just one of the pool tokens
abstract contract WidoZapper_ERC20_ERC721 is IERC721Receiver {
    using LowGasSafeMath for uint256;
    using SafeERC20 for IERC20;

    error NotEnoughSupply();

    struct Asset {
        uint256 reserves;
        address token;
    }

    /// @notice Add liquidity to a pool using one of the pool tokens
    /// @param router Address of the ISwapRouter02 contract
    /// @param pool Address of the pool contract to add liquidity into
    /// @param fromToken Address of the token to swap
    /// @param amount Amount of the from token to spend on the user's behalf
    /// @param minToToken Minimum amount of the pool token the user is willing to accept
    function zapIn(
        ISwapRouter02 router,
        IUniswapV3Pool pool,
        INonfungiblePositionManager positionManager,
        address fromToken,
        address recipient,
        uint256 amount,
        uint256 minToToken,
        bytes memory extra
    ) external {
        IERC20(fromToken).safeTransferFrom(msg.sender, address(this), amount);

        (uint256 toTokenAmount, uint256 tokenId) = _swapAndAddLiquidity(
            router, pool, positionManager, fromToken, amount, extra
        );

        require(toTokenAmount >= minToToken, "Slippage too high");

        uint256 dust = IERC20(pool.token0()).balanceOf(address(this));
        if (dust > 0) {
            IERC20(pool.token0()).safeTransfer(recipient, dust);
        }
        dust = IERC20(pool.token1()).balanceOf(address(this));
        if (dust > 0) {
            IERC20(pool.token1()).safeTransfer(recipient, dust);
        }

        positionManager.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    /// @notice Remove liquidity from a pool into one of the pool tokens
    /// @param router Address of the UniswapV2Router02 contract
    /// @param pool Address of the pool contract to remove liquidity from
    /// @param tokenId Token ID that user wants to sell
    /// @param toToken Address of the to token
    /// @param minToToken Minimum amount of the to token the user is willing to accept
    function zapOut(
        ISwapRouter02 router,
        IUniswapV3Pool pool,
        INonfungiblePositionManager positionManager,
        uint256 tokenId,
        address toToken,
        uint256 minToToken,
        bytes memory extra
    ) external {
        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        uint256 toTokenAmount = _removeLiquidityAndSwap(router, pool, positionManager, toToken, tokenId, extra);
        require(toTokenAmount >= minToToken, "Slippage too high");

        IERC20(toToken).safeTransfer(msg.sender, toTokenAmount);
    }

    /// @notice Calculate the amount of pool tokens received when adding liquidity to an UniswapV2 pool using a single asset
    /// @param router Address of the UniswapV2Router02 contract
    /// @param pool Address of the pool contract to add liquidity into
    /// @param fromToken Address of the from token
    /// @param amount Amount of the from token
    /// @return minToToken Minimum amount of the lp token the user would receive in a no-slippage scenario.
    function calcMinToAmountForZapIn(
        ISwapRouter02 router,
        IUniswapV3Pool pool,
        INonfungiblePositionManager positionManager,
        address fromToken,
        uint256 amount,
        bytes calldata extra
    ) external view virtual returns (uint256 minToToken);

    /// @notice Calculate the amount of to tokens received when removing liquidity from an UniswapV2 pool into a single asset.
    /// @param router Address of the UniswapV2Router02 contract
    /// @param pool Address of the pool contract to remove liquidity from
    /// @param toToken Address of the to token
    /// @param lpAmount Amount of the lp token
    /// @return minToToken Minimum amount of the to token the user would receive in a no-slippage scenario.
    function calcMinToAmountForZapOut(
        ISwapRouter02 router,
        IUniswapV3Pool pool,
        INonfungiblePositionManager positionManager,
        address toToken,
        uint256 lpAmount,
        bytes calldata extra
    ) external view virtual returns (uint256 minToToken);

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @notice Balances the amounts and adds liquidity to the pool
    function _swapAndAddLiquidity(
        ISwapRouter02 router,
        IUniswapV3Pool pool,
        INonfungiblePositionManager positionManager,
        address fromToken,
        uint256 amountIn,
        bytes memory extra
    ) internal virtual returns (uint256 addedLiquidity, uint256 tokenId);

    /// @notice Removes liquidity from the pool and converts everything to a single asset
    function _removeLiquidityAndSwap(
        ISwapRouter02 router,
        IUniswapV3Pool pool,
        INonfungiblePositionManager positionManager,
        address toToken,
        uint256 tokenId,
        bytes memory extra
    ) internal virtual returns (uint256);

    /// @notice Approves the tokens when not enough allowance
    function _approveTokenIfNeeded(address token, address spender, uint256 amount) internal {
        if (IERC20(token).allowance(address(this), spender) < amount) {
            IERC20(token).safeIncreaseAllowance(spender, amount);
        }
    }
}
