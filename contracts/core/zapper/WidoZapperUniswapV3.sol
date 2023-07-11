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
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@cryptoalgebra/periphery/contracts/libraries/LiquidityAmounts.sol";
import "@cryptoalgebra/core/contracts/libraries/TickMath.sol";

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @dev Setting `amountIn` to 0 will cause the contract to look up its own balance,
    /// and swap the entire amount, enabling contracts to send tokens before calling this function.
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

}

interface IUniswapV3Pool {
    function fee() external view returns (uint24);
    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    function slot0()
    external
    view
    returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );

}

interface INonfungiblePositionManager {

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /// @notice Creates a new position wrapped in a NFT
    /// @dev Call this when the pool does exist and is initialized. Note that if the pool is created but not initialized
    /// a method does not exist, i.e. the pool is assumed to be initialized.
    /// @param params The params necessary to mint a position, encoded as `MintParams` in calldata
    /// @return tokenId The ID of the token that represents the minted position
    /// @return liquidity The amount of liquidity for this position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function mint(MintParams calldata params)
    external
    payable
    returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Decreases the amount of liquidity in a position and accounts it to the position
    /// @param params tokenId The ID of the token for which liquidity is being decreased,
    /// amount The amount by which liquidity will be decreased,
    /// amount0Min The minimum amount of token0 that should be accounted for the burned liquidity,
    /// amount1Min The minimum amount of token1 that should be accounted for the burned liquidity,
    /// deadline The time by which the transaction must be included to effect the change
    /// @return amount0 The amount of token0 accounted to the position's tokens owed
    /// @return amount1 The amount of token1 accounted to the position's tokens owed
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
    external
    payable
    returns (uint256 amount0, uint256 amount1);

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /// @notice Returns the position information associated with a given token ID.
    /// @dev Throws if the token ID is not valid.
    /// @param tokenId The ID of the token that represents the position
    /// @return nonce The nonce for permits
    /// @return operator The address that is approved for spending
    /// @return token0 The address of the token0 for a specific pool
    /// @return token1 The address of the token1 for a specific pool
    /// @return fee The fee associated with the pool
    /// @return tickLower The lower end of the tick range for the position
    /// @return tickUpper The higher end of the tick range for the position
    /// @return liquidity The liquidity of the position
    /// @return feeGrowthInside0LastX128 The fee growth of token0 as of the last action on the individual position
    /// @return feeGrowthInside1LastX128 The fee growth of token1 as of the last action on the individual position
    /// @return tokensOwed0 The uncollected amount of token0 owed to the position as of the last computation
    /// @return tokensOwed1 The uncollected amount of token1 owed to the position as of the last computation
    function positions(uint256 tokenId)
    external
    view
    returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );
    /// @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
    /// @param params tokenId The ID of the NFT for which tokens are being collected,
    /// recipient The account that should receive the tokens,
    /// amount0Max The maximum amount of token0 to collect,
    /// amount1Max The maximum amount of token1 to collect
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice Burns a token ID, which deletes it from the NFT contract. The token must have 0 liquidity and all tokens
    /// must be collected first.
    /// @param tokenId The ID of the token that is being burned
    function burn(uint256 tokenId) external payable;

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/// @title Gamma pools Zapper
/// @notice Add or remove liquidity from Gamma pools using just one of the pool tokens
contract WidoZapperUniswapV3 is WidoZapper, IERC721Receiver {
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

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @inheritdoc WidoZapper
    function calcMinToAmountForZapIn(
        IUniswapV2Router02, //router,
        IUniswapV2Pair pair,
        address fromToken,
        uint256 amount,
        bytes calldata extra
    ) external view virtual override returns (uint256 minToToken) {
        IUniswapV3Pool pool = IUniswapV3Pool(address(pair));
        bool isZapFromToken0 = pool.token0() == fromToken;
        require(isZapFromToken0 || pool.token1() == fromToken, "Input token not present in liquidity pool");

        (int24 lowerTick,int24 upperTick, ) = abi.decode(extra, (int24, int24, address));

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

    /// @inheritdoc WidoZapper
    function calcMinToAmountForZapOut(
        IUniswapV2Router02, // router,
        IUniswapV2Pair pair,
        address toToken,
        uint256 amount,
        bytes calldata extra
    ) external view virtual override returns (uint256 minToToken) {
        IUniswapV3Pool pool = IUniswapV3Pool(address(pair));
        bool isZapToToken0 = pool.token0() == toToken;
        require(isZapToToken0 || pool.token1() == toToken, "Output token not present in liquidity pool");

        uint160 sqrtRatioAX96;
        uint160 sqrtRatioBX96;
        (uint160 sqrtPriceX96, , , , , ,) = pool.slot0();
        {
            (int24 lowerTick,int24 upperTick,) = abi.decode(extra, (int24, int24, address));
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

    /// @inheritdoc WidoZapper
    function _swapAndAddLiquidity(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address fromToken,
        bytes memory extra
    ) internal override returns (uint256 liquidity) {
        IUniswapV3Pool pool = IUniswapV3Pool(address(pair));
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint amount = IERC20(fromToken).balanceOf(address(this));

        bool isZapFromToken0 = token0 == fromToken;
        require(isZapFromToken0 || token1 == fromToken, "Input token not present in liquidity pool");

        uint256 amount0;
        uint256 amount1;
        {
            (int24 lowerTick,int24 upperTick,address nonfungiblePositionManager) = abi.decode(extra, (int24, int24, address));
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
                _swap(address(router), pool, amount - amount0, fromToken, token1);
            }
        } else {
            if (amount - amount1 > 0) {
                _swap(address(router), pool, amount - amount1, fromToken, token0);
            }
        }

        amount0 = IERC20(token0).balanceOf(address(this));
        amount1 = IERC20(token1).balanceOf(address(this));


        (int24 lowerTick,int24 upperTick,address nonfungiblePositionManager) = abi.decode(extra, (int24, int24, address));
        _approveTokenIfNeeded(token0, nonfungiblePositionManager, amount0);
        _approveTokenIfNeeded(token1, nonfungiblePositionManager, amount1);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0 : token0,
            token1 : token1,
            fee : pool.fee(),
            tickLower : lowerTick,
            tickUpper : upperTick,
            amount0Desired : amount0,
            amount1Desired : amount1,
            amount0Min : 0,
            amount1Min : 0,
            recipient : address(this),
            deadline : block.timestamp
        });

        uint tokenId;
        (tokenId, liquidity,,) = INonfungiblePositionManager(nonfungiblePositionManager).mint(params);

        INonfungiblePositionManager(nonfungiblePositionManager).safeTransferFrom(address(this), msg.sender, tokenId);
    }

    /// @inheritdoc WidoZapper
    function _removeLiquidityAndSwap(
        IUniswapV2Router02 router,
        IUniswapV2Pair pair,
        address toToken,
        bytes memory extra
    ) internal virtual override returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(address(pair));
        (,, INonfungiblePositionManager nonfungiblePositionManager, uint256 tokenId) = abi.decode(extra, (int24, int24, INonfungiblePositionManager, uint256));
        bool isZapToToken0;
        {
            address token0 = pool.token0();
            address token1 = pool.token1();
            isZapToToken0 = token0 == toToken;
            require(isZapToToken0 || token1 == toToken, "Output token not present in liquidity pool");
        }
        INonfungiblePositionManager.DecreaseLiquidityParams memory params;
        {

            (, , , , , , , uint128 liquidity, , , ,) = nonfungiblePositionManager.positions(tokenId);
            params = INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId : tokenId,
                liquidity : liquidity,
                amount0Min : 0,
                amount1Min : 0,
                deadline : block.timestamp
            });
        }

        (uint amount0, uint amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
        {

            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId : tokenId,
                    recipient : address(this),
                    amount0Max : type(uint128).max,
                    amount1Max : type(uint128).max
                })
            );
            nonfungiblePositionManager.burn(tokenId);
        }

        if (isZapToToken0) {
            if (amount1 > 0) {
                _swap(address(router), pool, amount1, pool.token1(), toToken);
            }
        } else {
            if (amount0 > 0) {
                _swap(address(router), pool, amount0, pool.token0(), toToken);
            }
        }

        uint256 toTokenAmount = IERC20(toToken).balanceOf(address(this));

        return toTokenAmount;
    }

    /// @dev This function swap amountIn through the path
    function _swap(
        address router,
        IUniswapV3Pool pool,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    )
    internal virtual
    returns (uint256 amountOut) {
        _approveTokenIfNeeded(tokenIn, router, amountIn);
        ISwapRouter02(router).exactInputSingle(
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
