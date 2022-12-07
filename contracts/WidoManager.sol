// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "solmate/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IWidoManager.sol";

contract WidoManager is IWidoManager, Ownable {
    using SafeTransferLib for ERC20;

    /// @notice Transfers tokens or native tokens from the user
    /// @param user The address of the order user
    /// @param token The address of the token to transfer (address(0) for native token)
    /// @param amount The amount if tokens to transfer from the user
    /// @dev amount must == msg.value when token == address(0)
    /// @return uint256 The amount of tokens or native tokens transferred from the user to this contract
    function pullTokens(
        address user,
        address token,
        uint256 amount
    ) external override onlyOwner returns (uint256) {
        ERC20(token).safeTransferFrom(user, owner(), amount);
        return amount;
    }
}
