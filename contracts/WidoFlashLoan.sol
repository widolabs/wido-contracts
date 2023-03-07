// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import {IERC3156FlashBorrower, IERC3156FlashLender} from "./interfaces/IERC3156.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWidoRouter} from "./interfaces/IWidoRouter.sol";
import {IWidoTokenManager} from "./interfaces/IWidoTokenManager.sol";

contract WidoFlashLoan is IERC3156FlashBorrower {
    IERC3156FlashLender public eulerFlashLoan;
    IWidoRouter public widoRouter;
    IWidoTokenManager public widoTokenManager;

    constructor(IERC3156FlashLender _eulerFlashLoan, IWidoRouter _widoRouter, IWidoTokenManager _widoTokenManager) {
        eulerFlashLoan = _eulerFlashLoan;
        widoRouter = _widoRouter;
        widoTokenManager = _widoTokenManager;
    }

    function swapCollateral(
        address token,
        uint256 amount,
        IWidoRouter.Order calldata order,
        IWidoRouter.Step[] calldata route,
        uint256 feeBps,
        address partner
    ) external {
        bytes memory data = abi.encode(order, route, feeBps, partner);
        eulerFlashLoan.flashLoan(IERC3156FlashBorrower(this), token, amount, data);
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        (IWidoRouter.Order memory order, IWidoRouter.Step[] memory route, uint256 feeBps, address partner) = abi.decode(
            data,
            (IWidoRouter.Order, IWidoRouter.Step[], uint256, address)
        );
        IERC20(token).approve(address(widoTokenManager), amount);
        IERC20(token).approve(address(eulerFlashLoan), amount);
        widoRouter.executeOrder(order, route, feeBps, partner);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
