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

/// @title Verse pools Zapper
/// @notice Add or remove liquidity from Verse Bitcoin.com pools using just one of the pool tokens
contract WidoZapperVerse is WidoZapperUniswapV2 {
    function _requires(IUniswapV2Router02 router, IUniswapV2Pair pair) internal override {
        // bytes4(keccak256('FACTORY()'))
        (bool success, bytes memory result) = address(router).call(hex"2dd31000");
        if (!success) {
            revert("Fail: VerseRouter factory");
        }
        address router_factory = abi.decode(result, (address));
        require(pair.factory() == router_factory, "Incompatible router and pair");
    }
}
