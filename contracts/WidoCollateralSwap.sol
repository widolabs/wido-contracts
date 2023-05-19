// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import {IERC3156FlashBorrower, IERC3156FlashLender} from "./interfaces/IERC3156.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IWidoRouter} from "./interfaces/IWidoRouter.sol";
import {IWidoTokenManager} from "./interfaces/IWidoTokenManager.sol";
import {IComet} from "./interfaces/IComet.sol";

contract WidoCollateralSwap is IERC3156FlashBorrower {
    using SafeMath for uint256;

    /// @dev The used flash loan provider
    IERC3156FlashLender immutable flashLoanProvider;

    /// @dev The typehash for the ERC-3156 `onFlashLoan` return
    bytes32 internal constant ON_FLASH_LOAN_RESPONSE = keccak256("ERC3156FlashBorrower.onFlashLoan");

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

    /// @notice Performs a collateral swap
    /// @param existingCollateral The collateral currently locked in the Comet contract
    /// @param finalCollateral The final collateral desired collateral
    /// @param sigs The required signatures to allow and revoke permission to this contract
    /// @param swap The necessary data to swap one collateral for the other
    /// @param comet The address of the Comet contract to interact with
    function swapCollateral(
        Collateral calldata existingCollateral,
        Collateral calldata finalCollateral,
        Signatures calldata sigs,
        WidoSwap calldata swap,
        address comet
    ) external {
        bytes memory data = abi.encode(
            msg.sender,
            comet,
            existingCollateral,
            sigs,
            swap
        );

        flashLoanProvider.flashLoan(
            IERC3156FlashBorrower(this),
            finalCollateral.addr,
            finalCollateral.amount,
            data
        );
    }

    /// @notice Callback to be executed by the flash loan provider
    /// @dev Only allow-listed providers should have access
    function onFlashLoan(
        address /* initiator */,
        address borrowedAsset,
        uint256 borrowedAmount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == address(flashLoanProvider), "Caller is not accepted provider");
        require(fee == 0, "Fee payment not supported yet");

        (
        address user,
        IComet comet,
        Collateral memory existingCollateral,
        Signatures memory signatures,
        WidoSwap memory swapDetails
        ) = abi.decode(
            data,
            (address, IComet, Collateral, Signatures, WidoSwap)
        );

        // supply new collateral on behalf of user
        _supplyTo(comet, user, borrowedAsset, borrowedAmount);

        // withdraw existing collateral
        _withdrawFrom(comet, user, existingCollateral, signatures);

        // execute swap
        _swap(existingCollateral, swapDetails);

        // check amount of surplus collateral
        uint256 surplusAmount = IERC20(borrowedAsset).balanceOf(address(this)) - borrowedAmount;

        // if positive slippage, supply extra to user
        if (surplusAmount > 0) {
            _supplyTo(comet, user, borrowedAsset, surplusAmount);
        }

        // approve loan provider to pull lent amount + fee
        IERC20(borrowedAsset).approve(
            address(flashLoanProvider),
            borrowedAmount.add(fee)
        );

        return ON_FLASH_LOAN_RESPONSE;
    }

    /// @dev Performs the swap of the collateral on the WidoRouter
    function _swap(
        Collateral memory collateral,
        WidoSwap memory swap
    ) internal {
        // approve WidoTokenManager initial collateral to make the swap
        IERC20(collateral.addr).approve(
            swap.tokenManager,
            collateral.amount
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

    /// @dev Supplies collateral on behalf of user
    function _supplyTo(
        IComet comet,
        address user,
        address asset,
        uint256 amount
    ) internal {
        IERC20(asset).approve(address(comet), amount);
        comet.supplyTo(user, asset, amount);
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
        unchecked { nonce++; }
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
