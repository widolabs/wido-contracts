// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import {IERC3156FlashBorrower, IERC3156FlashLender} from "./interfaces/IERC3156.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IComet} from "./interfaces/IComet.sol";
import {LibCollateralSwap} from "./libraries/LibCollateralSwap.sol";
import {IWidoCollateralSwap} from "./interfaces/IWidoCollateralSwap.sol";
import {WidoRouter} from "../core/WidoRouter.sol";

/// @title WidoCollateralSwap_ERC3156
/// @notice Contract enables swaps between arbitrary tokens and integrates ERC-3156 compliant flash loan services.
contract WidoCollateralSwap_ERC3156 is IERC3156FlashBorrower, IWidoCollateralSwap, ReentrancyGuard {
    using SafeMath for uint256;

    /// @dev ERC3156 lender contract
    IERC3156FlashLender public immutable loanProvider;

    /// @dev The typehash for the ERC-3156 `onFlashLoan` return
    bytes32 internal constant ON_FLASH_LOAN_RESPONSE = keccak256("ERC3156FlashBorrower.onFlashLoan");
    
    /// @dev Comet Market contract
    IComet public immutable COMET_MARKET;

    /// @dev Wido Router contract
    address public immutable WIDO_ROUTER;

    /// @dev Wido Token Manager contract
    address public immutable WIDO_TOKEN_MANAGER;

    error InvalidProvider();
    error InvalidInitiator();

    constructor(IERC3156FlashLender _loanProvider, IComet _cometMarket, address payable _widoRouter) {
        loanProvider = _loanProvider;
        COMET_MARKET = _cometMarket;
        WIDO_ROUTER = _widoRouter;
        WIDO_TOKEN_MANAGER = address(WidoRouter(_widoRouter).widoTokenManager());
    }

    /// @notice Performs a collateral swap
    /// @param existingCollateral The collateral currently locked in the Comet contract
    /// @param finalCollateral The final collateral desired collateral
    /// @param sigs The required signatures to allow and revoke permission to this contract
    /// @param swapCallData The calldata to swap one collateral for the other
    function swapCollateral(
        LibCollateralSwap.Collateral calldata existingCollateral,
        LibCollateralSwap.Collateral calldata finalCollateral,
        LibCollateralSwap.Signatures calldata sigs,
        bytes calldata swapCallData
    ) external override {
        bytes memory data = abi.encode(
            msg.sender,
            COMET_MARKET,
            existingCollateral,
            sigs,
            LibCollateralSwap.WidoSwap(WIDO_ROUTER, WIDO_TOKEN_MANAGER, swapCallData)
        );

        loanProvider.flashLoan(
            IERC3156FlashBorrower(this),
            finalCollateral.addr,
            finalCollateral.amount,
            data
        );
    }

    /// @notice The function performs a collateral swap, after checking the legitimacy of the loan provider.
    /// After the swap, it approves the loan provider to withdraw the borrowed amount and the fee.
    /// @dev This function is the callback executed by the flash loan provider after loan disbursement.
    /// Only allowed providers can initiate the callback.
    /// @param borrowedAsset The address of the asset that has been borrowed.
    /// @param borrowedAmount The amount of the asset that has been borrowed.
    /// @param fee The fee associated with the borrowed asset.
    /// @param data Encoded payload provided by the flash loan initiator containing details for the swap.
    /// @return Returns the standard flash loan response of the callback function.
    function onFlashLoan(
        address initiator,
        address borrowedAsset,
        uint256 borrowedAmount,
        uint256 fee,
        bytes calldata data
    ) external override nonReentrant returns (bytes32) {
        if (initiator != address(this)) {
            revert InvalidInitiator();
        }
        if (msg.sender != address(loanProvider)) {
            revert InvalidProvider();
        }

        LibCollateralSwap.performCollateralSwap(borrowedAsset, borrowedAmount, fee, data);

        // approve loan provider to pull lent amount + fee
        IERC20(borrowedAsset).approve(
            address(loanProvider),
            borrowedAmount.add(fee)
        );

        return ON_FLASH_LOAN_RESPONSE;
    }
}
