// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import {IERC3156FlashBorrower, IERC3156FlashLender} from "./interfaces/IERC3156.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWidoRouter} from "./interfaces/IWidoRouter.sol";
import {IWidoTokenManager} from "./interfaces/IWidoTokenManager.sol";
import {IComet} from "./interfaces/IComet.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WidoCollateralSwap is IERC3156FlashBorrower {
    using SafeMath for uint256;

    IERC3156FlashLender public flashLoanProvider;

    struct Collateral {
        address addr;
        uint256 amount;
    }

    struct Signatures {
        Signature allow;
        Signature revoke;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct WidoSwap {
        address router;
        address tokenManager;
        bytes callData;
    }

    constructor(IERC3156FlashLender _flashLoanProvider) {
        flashLoanProvider = _flashLoanProvider;
    }

    function swapCollateral(
        Collateral calldata existingCollateral,
        Collateral calldata finalCollateral,
        Signatures calldata sigs,
        WidoSwap calldata swap,
        address comet
    ) external {
        bytes memory data = abi.encode(
            msg.sender,
            existingCollateral,
            sigs,
            swap,
            comet
        );

        flashLoanProvider.flashLoan(
            IERC3156FlashBorrower(this),
            finalCollateral.addr,
            finalCollateral.amount,
            data
        );
    }

    function onFlashLoan(
        address /* initiator */,
        address lentAsset,
        uint256 lentAmount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == address(flashLoanProvider), "Caller is not Euler");
        (
        address user,
        Collateral memory existingCollateral,
        Signatures memory signatures,
        WidoSwap memory swap,
        IComet comet
        ) = abi.decode(
            data,
            (address, Collateral, Signatures, WidoSwap, IComet)
        );

        // supply new collateral on behalf of user
        IERC20(lentAsset).approve(address(comet), lentAmount);
        comet.supplyTo(user, lentAsset, lentAmount);

        // withdraw existing collateral
        _withdrawFrom(comet, user, existingCollateral, signatures);

        {
            // approve WidoTokenManager initial collateral to make the swap
            IERC20(existingCollateral.addr).approve(
                swap.tokenManager,
                existingCollateral.amount
            );

            // execute swap
            (bool success, bytes memory result) = swap.router.call(swap.callData);

            if (!success) {
                if (result.length < 68) revert("WidoRouter failed");
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }
        }

        // approve loan provider to pull lent amount + fee
        IERC20(lentAsset).approve(
            address(flashLoanProvider),
            lentAmount.add(fee)
        );

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev This function withdraws the collateral from the user.
    ///  It requires two consecutive EIP712 signatures to allow and revoke
    ///  permissions to and from this contract.
    function _withdrawFrom(
        IComet comet,
        address user,
        Collateral memory collateral,
        Signatures memory sigs
    ) internal {
        // get current nonce
        uint256 nonce = comet.userNonce(user);
        // allow the contract
        _allowBySig(comet, user, true, nonce, sigs.allow);
        // withdraw assets
        comet.withdrawFrom(user, address(this), collateral.addr, collateral.amount);
        // increment nonce
        unchecked {nonce++;}
        // revoke permission
        _allowBySig(comet, user, false, nonce, sigs.revoke);
    }

    /// @dev Executes a single `allowBySig` operation on the Comet contract
    function _allowBySig(
        IComet comet,
        address user,
        bool allowed,
        uint256 nonce,
        Signature memory sig
    ) internal {
        comet.allowBySig(
            user,
            address(this),
            allowed,
            nonce,
            10e9,
            sig.v,
            sig.r,
            sig.s
        );
    }

}
