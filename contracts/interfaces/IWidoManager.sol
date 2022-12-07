// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

interface IWidoManager {
    function pullTokens(
        address user,
        address token,
        uint256 amount
    ) external returns (uint256);
}
