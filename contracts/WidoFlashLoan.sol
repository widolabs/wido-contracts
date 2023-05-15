// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import {IERC3156FlashBorrower, IERC3156FlashLender} from "./interfaces/IERC3156.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWidoRouter} from "./interfaces/IWidoRouter.sol";
import {IWidoTokenManager} from "./interfaces/IWidoTokenManager.sol";
import {IComet} from "./interfaces/IComet.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WidoFlashLoan is IERC3156FlashBorrower {
    using SafeMath for uint256;
    IERC3156FlashLender public flashLoanProvider;
    IWidoRouter public widoRouter;
    IWidoTokenManager public widoTokenManager;
    IComet public comet;

    constructor(
        IERC3156FlashLender _flashLoanProvider,
        IWidoRouter _widoRouter,
        IWidoTokenManager _widoTokenManager,
        IComet _comet
    ) {
        flashLoanProvider = _flashLoanProvider;
        widoRouter = _widoRouter;
        widoTokenManager = _widoTokenManager;
        comet = _comet;
    }

    function swapCollateral(
        address finalCollateral,
        uint256 finalCollateralAmount,
        address initialCollateral,
        uint256 initialCollateralAmount,
        IWidoRouter.Step[] calldata route,
        uint256 feeBps,
        address partner
    ) external {
        bytes memory data = abi.encode(msg.sender, initialCollateral, initialCollateralAmount, route, feeBps, partner);

        // approve finalCollateralAmount+fee


        flashLoanProvider.flashLoan(IERC3156FlashBorrower(this), finalCollateral, finalCollateralAmount, data);
    }

    function onFlashLoan(
        address initiator,
        address lentAsset,
        uint256 lentAmount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == address(flashLoanProvider), "Caller is not Euler");
        (
            address user,
            address existingAsset,
            uint256 existingAssetAmount,
            IWidoRouter.Step[] memory route,
            uint256 feeBps,
            address partner
        ) = abi.decode(data, (address, address, uint256, IWidoRouter.Step[], uint256, address));

        // supply new collateral on behalf of user
        IERC20(lentAsset).approve(address(comet), lentAmount);
        comet.supplyTo(user, lentAsset, lentAmount);

        // withdraw previous collateral (user must've approved)
        comet.withdrawFrom(user, address(this), existingAsset, existingAssetAmount);

        {
            // approve WidoTokenManager initial collateral to make the swap
            IERC20(existingAsset).approve(address(widoTokenManager), existingAssetAmount);

            // create Route
            IWidoRouter.OrderInput[] memory inputs = new IWidoRouter.OrderInput[](1);
            inputs[0] = IWidoRouter.OrderInput(existingAsset, existingAssetAmount);

            IWidoRouter.OrderOutput[] memory outputs = new IWidoRouter.OrderOutput[](1);
            outputs[0] = IWidoRouter.OrderOutput(lentAsset, lentAmount);

            IWidoRouter.Order memory order = IWidoRouter.Order(inputs, outputs, address(this), 0, 0);

            // execute swap
            widoRouter.executeOrder(order, route, feeBps, partner);
        }

        // approve loan provider to pull lent amount + fee
        IERC20(lentAsset).approve(
            address(flashLoanProvider),
            lentAmount.add(fee)
        );

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
