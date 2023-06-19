// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../shared/OptimismForkTest.sol";
import "../../contracts/core/WidoZapperVelodrome.sol";

contract WidoZapperVelodromeTest is OptimismForkTest {
    using SafeMath for uint256;

    WidoZapperVelodrome zapper;

    address constant VELO_ROUTER = address(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
    address constant WBTC_USDC_LP = address(0x4C8B195d33c6F95A8262D56Ede793611ee7b5AAD);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperVelodrome();
        vm.label(address(zapper), "Zapper");

        vm.label(VELO_ROUTER, "VELO_ROUTER");
        vm.label(WBTC_USDC_LP, "WBTC_USDC_LP");
    }

    function test_zapUSDCForLP() public {
        /** Arrange */

        uint256 amount = 50_000_000;
        address fromAsset = USDC;
        address toAsset = WBTC_USDC_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapWBTCForLP() public {
        /** Arrange */

        uint256 amount = 200_000;
        address fromAsset = WBTC;
        address toAsset = WBTC_USDC_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForUSDC() public {
        /** Arrange */

        _zapIn(zapper, USDC, 50_000_000);

        address fromAsset = WBTC_USDC_LP;
        address toAsset = USDC;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForWBTC() public {
        /** Arrange */

        _zapIn(zapper, WBTC, 200_000);

        address fromAsset = WBTC_USDC_LP;
        address toAsset = WBTC;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_revertWhen_zapWBTCForLP_HasHighSlippage() public {
        /** Arrange */

        uint256 amount = 200_000;
        address fromAsset = WBTC;
        deal(fromAsset, user1, amount);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(VELO_ROUTER),
            IUniswapV2Pair(WBTC_USDC_LP),
            fromAsset,
            amount
        )
        .mul(1001)
        .div(1000);

        vm.startPrank(user1);

        IERC20(fromAsset).approve(address(zapper), amount);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapIn(
            IUniswapV2Router02(VELO_ROUTER),
            IUniswapV2Pair(WBTC_USDC_LP),
            fromAsset,
            amount,
            minToToken,
            bytes("")
        );
    }

    function test_revertWhen_zapWBTCForLP_NoApproval() public {
        /** Arrange */

        uint256 amount = 200_000;
        address fromAsset = WBTC;
        deal(fromAsset, user1, amount);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(VELO_ROUTER),
            IUniswapV2Pair(WBTC_USDC_LP),
            fromAsset,
            amount
        )
        .mul(998)
        .div(1000);

        vm.startPrank(user1);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapIn(
            IUniswapV2Router02(VELO_ROUTER),
            IUniswapV2Pair(WBTC_USDC_LP),
            fromAsset,
            amount,
            minToToken,
            bytes("")
        );
    }

    function test_revertWhen_zapLPForWBTC_NoBalance() public {
        /** Arrange */

        address fromAsset = WBTC_USDC_LP;
        address toAsset = WBTC;
        uint256 amount = 1 ether;

        uint256 minToToken = zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(VELO_ROUTER),
            IUniswapV2Pair(WBTC_USDC_LP),
            toAsset,
            amount
        )
        .mul(998)
        .div(1000);

        vm.startPrank(user1);

        IERC20(fromAsset).approve(address(zapper), amount);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapOut(
            IUniswapV2Router02(VELO_ROUTER),
            IUniswapV2Pair(WBTC_USDC_LP),
            amount,
            toAsset,
            minToToken,
            bytes("")
        );
    }

    function _zapIn(
        WidoZapperUniswapV2 _zapper,
        address _fromAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        deal(_fromAsset, user1, _amountIn);
        vm.startPrank(user1);

        minToToken = _zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(VELO_ROUTER),
            IUniswapV2Pair(WBTC_USDC_LP),
            _fromAsset,
            _amountIn
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            IUniswapV2Router02(VELO_ROUTER),
            IUniswapV2Pair(WBTC_USDC_LP),
            _fromAsset,
            _amountIn,
            minToToken,
            abi.encode(false)
        );
    }

    function _zapOut(
        WidoZapperUniswapV2 _zapper,
        address _fromAsset,
        address _toAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        minToToken = _zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(VELO_ROUTER),
            IUniswapV2Pair(WBTC_USDC_LP),
            _toAsset,
            _amountIn
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapOut(
            IUniswapV2Router02(VELO_ROUTER),
            IUniswapV2Pair(WBTC_USDC_LP),
            _amountIn,
            _toAsset,
            minToToken,
            abi.encode(false)
        );
    }
}
