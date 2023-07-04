// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../contracts/core/zapper/WidoZapperUniswapV2.sol";
import "../../shared/PolygonForkTest.sol";

contract WidoZapperApeSwapTest is PolygonForkTest {
    using SafeMath for uint256;

    // ApeSwap uses an exact clone of UniV2
    WidoZapperUniswapV2 zapper;

    address constant UNI_ROUTER = address(0xC0788A3aD43d79aa53B09c2EaCc313A787d1d607);
    address constant WOMBAT_USDC_LP = address(0x20D4c6f341a7c87B1944D456d8674849Ca1001aE);
    address constant WOMBAT = address(0x0C9c7712C83B3C70e7c5E11100D33D9401BdF9dd);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperUniswapV2();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");
        vm.label(WOMBAT_USDC_LP, "WOMBAT_USDC_LP");
    }

    function test_zapUSDCForLP() public {
        /** Arrange */

        uint256 amount = 150_000_000;
        address fromAsset = USDC;
        address toAsset = WOMBAT_USDC_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapWOMBATForLP() public {
        /** Arrange */

        uint256 amount = 0.5 ether;
        address fromAsset = WOMBAT;
        address toAsset = WOMBAT_USDC_LP;

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

        _zapIn(zapper, USDC, 150_000_000);

        address fromAsset = WOMBAT_USDC_LP;
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

    function test_zapLPForWOMBAT() public {
        /** Arrange */

        _zapIn(zapper, WOMBAT, 0.5 ether);

        address fromAsset = WOMBAT_USDC_LP;
        address toAsset = WOMBAT;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_revertWhen_zapWOMBATForLP_HasHighSlippage() public {
        /** Arrange */

        uint256 amount = 0.5 ether;
        address fromAsset = WOMBAT;
        deal(fromAsset, user1, amount);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WOMBAT_USDC_LP),
            fromAsset,
            amount,
            bytes("")
        )
        .mul(1005)
        .div(1000);

        vm.startPrank(user1);

        IERC20(fromAsset).approve(address(zapper), amount);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WOMBAT_USDC_LP),
            fromAsset,
            amount,
            minToToken,
            bytes("")
        );
    }

    function test_revertWhen_zapWOMBATForLP_NoApproval() public {
        /** Arrange */

        uint256 amount = 0.5 ether;
        address fromAsset = WOMBAT;
        deal(fromAsset, user1, amount);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WOMBAT_USDC_LP),
            fromAsset,
            amount,
            bytes("")
        )
        .mul(998)
        .div(1000);

        vm.startPrank(user1);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WOMBAT_USDC_LP),
            fromAsset,
            amount,
            minToToken,
            bytes("")
        );
    }

    function test_revertWhen_zapLPForWOMBAT_NoBalance() public {
        /** Arrange */

        address fromAsset = WOMBAT_USDC_LP;
        address toAsset = WOMBAT;
        uint256 amount = 1 ether;

        uint256 minToToken = zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WOMBAT_USDC_LP),
            toAsset,
            amount,
            bytes("")
        )
        .mul(998)
        .div(1000);

        vm.startPrank(user1);

        IERC20(fromAsset).approve(address(zapper), amount);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WOMBAT_USDC_LP),
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
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WOMBAT_USDC_LP),
            _fromAsset,
            _amountIn,
            bytes("")
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WOMBAT_USDC_LP),
            _fromAsset,
            _amountIn,
            minToToken,
            bytes("")
        );
    }

    function _zapOut(
        WidoZapperUniswapV2 _zapper,
        address _fromAsset,
        address _toAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        minToToken = _zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WOMBAT_USDC_LP),
            _toAsset,
            _amountIn,
            bytes("")
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WOMBAT_USDC_LP),
            _amountIn,
            _toAsset,
            minToToken,
            bytes("")
        );
    }
}
