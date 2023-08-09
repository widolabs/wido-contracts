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

/// @title Gamma pools Zapper
/// @notice Add or remove liquidity from Gamma pools using just one of the pool tokens
contract WidoZapperGammaRetro is WidoZapperGammaAlgebra {
    function _sqrtRatioX96(address _pool) internal view virtual override returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,,,,) = IUniswapV3Pool(_pool).slot0();
    }
}
