// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import {IERC3156FlashBorrower, IERC3156FlashLender} from "./interfaces/IERC3156.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWidoRouter} from "./interfaces/IWidoRouter.sol";
import {IWidoTokenManager} from "./interfaces/IWidoTokenManager.sol";
import {IComet} from "./interfaces/IComet.sol";

contract WidoFlashLoan is IERC3156FlashBorrower {
    IERC3156FlashLender public eulerFlashLoan;
    IWidoRouter public widoRouter;
    IWidoTokenManager public widoTokenManager;
    IComet public comet;

    constructor(
        IERC3156FlashLender _eulerFlashLoan,
        IWidoRouter _widoRouter,
        IWidoTokenManager _widoTokenManager,
        IComet _comet
    ) {
        eulerFlashLoan = _eulerFlashLoan;
        widoRouter = _widoRouter;
        widoTokenManager = _widoTokenManager;
        comet = _comet;
    }

    function swapCollateral(
        address token,
        uint256 amount,
        address toSwap,
        uint256 toSwapAmount,
        IWidoRouter.Step[] calldata route,
        uint256 feeBps,
        address partner
    ) external {
        // encode off-chain to save gas?
        bytes memory data = abi.encode(msg.sender, toSwap, toSwapAmount, route, feeBps, partner);

        // approve amount+fee


        eulerFlashLoan.flashLoan(IERC3156FlashBorrower(this), token, amount, data);
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {

        require(msg.sender == address(eulerFlashLoan), "Caller is not Euler");
        (
            address user,
            address toSwap,
            uint256 toSwapAmount,
            IWidoRouter.Step[] memory route,
            uint256 feeBps,
            address partner
        ) = abi.decode(data, (address, address, uint256, IWidoRouter.Step[], uint256, address));

        IERC20(token).approve(address(comet), amount);
        comet.supplyTo(user, token, amount);
        comet.withdrawFrom(user, address(this), toSwap, toSwapAmount);

        IERC20(toSwap).approve(address(widoTokenManager), toSwapAmount);
        IERC20(token).approve(address(eulerFlashLoan), amount);

        IWidoRouter.OrderInput[] memory inputs = new IWidoRouter.OrderInput[](1);
        inputs[0] = IWidoRouter.OrderInput(toSwap, toSwapAmount);

        IWidoRouter.OrderOutput[] memory outputs = new IWidoRouter.OrderOutput[](1);
        outputs[0] = IWidoRouter.OrderOutput(token, amount);

        IWidoRouter.Order memory order = IWidoRouter.Order(inputs, outputs, address(this), 0, 0);
        widoRouter.executeOrder(order, route, feeBps, partner);



        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
