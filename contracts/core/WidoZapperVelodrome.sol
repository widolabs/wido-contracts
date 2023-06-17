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

interface VelodromeRouter {
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
}

/// @title Velodrome pools Zapper
/// @notice Add or remove liquidity from Velodrome pools using just one of the pool tokens
contract WidoZapperVelodrome is WidoZapperUniswapV2 {

    /// @dev This function quotes the expected amountB given a certain amountA, while the pool has the specified reserves
    ///  code is copied here from the VelodromeRouter because the function is defined as internal
    ///  https://github.com/velodrome-finance/contracts/blob/master/contracts/Router.sol#L58
    function _quote(
        IUniswapV2Router02, //router
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    )
    internal pure virtual override
    returns (uint256 amountB) {
        require(amountA > 0, 'Router: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'Router: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }

    /// @dev This function adds liquidity into the pool
    function _addLiquidity(
        IUniswapV2Router02 router,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        bytes memory extra
    )
    internal virtual override
    returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        bool stable = abi.decode(extra, (bool));
        return VelodromeRouter(address(router)).addLiquidity(
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

}
