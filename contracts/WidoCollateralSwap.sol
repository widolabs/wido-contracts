// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import {IERC3156FlashBorrower, IERC3156FlashLender} from "./interfaces/IERC3156.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IFlashLoanSimpleReceiver} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IWidoRouter} from "./interfaces/IWidoRouter.sol";
import {IWidoTokenManager} from "./interfaces/IWidoTokenManager.sol";
import {IComet} from "./interfaces/IComet.sol";

contract WidoCollateralSwap is IERC3156FlashBorrower, IFlashLoanSimpleReceiver {
    using SafeMath for uint256;

    /// @dev Equalizer lender contract
    IERC3156FlashLender public immutable equalizerProvider;

    /// @dev Aave addresses provider contract
    IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;

    /// @dev Aave Pool contract
    IPool public immutable override POOL;

    /// @dev The typehash for the ERC-3156 `onFlashLoan` return
    bytes32 internal constant ON_FLASH_LOAN_RESPONSE = keccak256("ERC3156FlashBorrower.onFlashLoan");

    error InvalidProvider();
    error FeeUnsupported();
    error WidoRouterFailed();

    enum Provider {
        Equalizer,
        Aave
    }

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

    constructor(IERC3156FlashLender _equalizerProvider, IPoolAddressesProvider _addressProvider) {
        equalizerProvider = _equalizerProvider;
        ADDRESSES_PROVIDER = _addressProvider;
        POOL = IPool(_addressProvider.getPool());
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
        address comet,
        Provider provider
    ) external {
        bytes memory data = abi.encode(
            msg.sender,
            comet,
            existingCollateral,
            sigs,
            swap
        );

        if (provider == Provider.Equalizer) {
            equalizerProvider.flashLoan(
                IERC3156FlashBorrower(this),
                finalCollateral.addr,
                finalCollateral.amount,
                data
            );
        }
        else if (provider == Provider.Aave) {
            POOL.flashLoanSimple(
                address(this),
                finalCollateral.addr,
                finalCollateral.amount,
                data,
                0
            );
        }
        else {
            revert InvalidProvider();
        }
    }

    /**
    * @notice Executes an operation after receiving the flash-borrowed asset
    * @dev Ensure that the contract can return the debt + premium, e.g., has
    *      enough funds to repay and has approved the Pool to pull the total amount
    * @param asset The address of the flash-borrowed asset
    * @param amount The amount of the flash-borrowed asset
    * @param premium The fee of the flash-borrowed asset
    * @param params The byte-encoded params passed when initiating the flashloan
    * @return True if the execution of the operation succeeds, false otherwise
    */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address /*initiator*/,
        bytes calldata params
    ) external override returns (bool) {
        if (msg.sender != address(POOL)) {
            revert InvalidProvider();
        }

        _performCollateralSwap(asset, amount, premium, params);

        // approve loan provider to pull lent amount + fee
        IERC20(asset).approve(
            address(POOL),
            amount.add(premium)
        );

        return true;
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
        if (msg.sender != address(equalizerProvider)) {
            revert InvalidProvider();
        }
        if (fee != 0) {
            revert FeeUnsupported();
        }

        _performCollateralSwap(borrowedAsset, borrowedAmount, fee, data);

        // approve loan provider to pull lent amount + fee
        IERC20(borrowedAsset).approve(
            address(equalizerProvider),
            borrowedAmount.add(fee)
        );

        return ON_FLASH_LOAN_RESPONSE;
    }

    /// @dev Performs all the steps to swap collaterals on the Comet contract
    function _performCollateralSwap(
        address borrowedAsset,
        uint256 borrowedAmount,
        uint256 fee,
        bytes memory data
    ) internal {
        // decode payload
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
        _supplyTo(comet, user, borrowedAsset, borrowedAmount.sub(fee));

        // withdraw existing collateral
        _withdrawFrom(comet, user, existingCollateral, signatures);

        // execute swap
        _swap(existingCollateral, swapDetails);

        // check amount of surplus collateral
        uint256 surplusAmount = IERC20(borrowedAsset).balanceOf(address(this)) - borrowedAmount - fee;

        // if positive slippage, supply extra to user
        if (surplusAmount > 0) {
            _supplyTo(comet, user, borrowedAsset, surplusAmount);
        }
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
            if (result.length < 68) revert WidoRouterFailed();
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
