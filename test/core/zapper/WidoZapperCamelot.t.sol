// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../contracts/core/zapper/WidoZapperCamelot.sol";
import "../../shared/ArbitrumForkTest.sol";

contract WidoZapperCamelotTest is ArbitrumForkTest {
    using SafeMath for uint256;

    WidoZapperCamelot zapper;

    address constant CAMELOT_ROUTER = address(0xc873fEcbd354f5A56E00E710B90EF4201db2448d);
    address constant WETH_ARB_LP = address(0xa6c5C7D189fA4eB5Af8ba34E63dCDD3a635D433f);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperCamelot();
        vm.label(address(zapper), "Zapper");

        vm.label(CAMELOT_ROUTER, "CAMELOT_ROUTER");
        vm.label(WETH_ARB_LP, "WETH_ARB_LP");
    }

    function test_zapARBForLP() public {
        /** Arrange */

        uint256 amount = 150_000_000;
        address fromAsset = ARB;
        address toAsset = WETH_ARB_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(IERC20(ARB).balanceOf(address(zapper)), 0, "Dust");
        assertEq(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapWETHForLP() public {
        /** Arrange */

        uint256 amount = 0.5 ether;
        address fromAsset = WETH;
        address toAsset = WETH_ARB_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(IERC20(ARB).balanceOf(address(zapper)), 0, "Dust");
        assertEq(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForARB() public {
        /** Arrange */

        _zapIn(zapper, ARB, 150_000_000);

        address fromAsset = WETH_ARB_LP;
        address toAsset = ARB;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(IERC20(ARB).balanceOf(address(zapper)), 0, "Dust");
        assertEq(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForWETH() public {
        /** Arrange */

        _zapIn(zapper, WETH, 0.5 ether);

        address fromAsset = WETH_ARB_LP;
        address toAsset = WETH;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(IERC20(ARB).balanceOf(address(zapper)), 0, "Dust");
        assertEq(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_revertWhen_zapARBForLP_HasHighSlippage() public {
        /** Arrange */

        uint256 amount = 0.5 ether;
        address fromAsset = WETH;
        deal(fromAsset, user1, amount);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(CAMELOT_ROUTER),
            IUniswapV2Pair(WETH_ARB_LP),
            fromAsset,
            amount,
            bytes("")
        )
        .mul(1002)
        .div(1000);

        vm.startPrank(user1);

        IERC20(fromAsset).approve(address(zapper), amount);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapIn(
            IUniswapV2Router02(CAMELOT_ROUTER),
            IUniswapV2Pair(WETH_ARB_LP),
            fromAsset,
            amount,
            minToToken,
            bytes("")
        );
    }

    function test_revertWhen_zapARBForLP_NoApproval() public {
        /** Arrange */

        uint256 amount = 0.5 ether;
        address fromAsset = WETH;
        deal(fromAsset, user1, amount);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(CAMELOT_ROUTER),
            IUniswapV2Pair(WETH_ARB_LP),
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
            IUniswapV2Router02(CAMELOT_ROUTER),
            IUniswapV2Pair(WETH_ARB_LP),
            fromAsset,
            amount,
            minToToken,
            bytes("")
        );
    }

    function test_revertWhen_zapLPForARB_NoBalance() public {
        /** Arrange */

        address fromAsset = WETH_ARB_LP;
        address toAsset = WETH;
        uint256 amount = 1 ether;

        uint256 minToToken = zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(CAMELOT_ROUTER),
            IUniswapV2Pair(WETH_ARB_LP),
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
            IUniswapV2Router02(CAMELOT_ROUTER),
            IUniswapV2Pair(WETH_ARB_LP),
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
            IUniswapV2Router02(CAMELOT_ROUTER),
            IUniswapV2Pair(WETH_ARB_LP),
            _fromAsset,
            _amountIn,
            bytes("")
        )
        .mul(996)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            IUniswapV2Router02(CAMELOT_ROUTER),
            IUniswapV2Pair(WETH_ARB_LP),
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
            IUniswapV2Router02(CAMELOT_ROUTER),
            IUniswapV2Pair(WETH_ARB_LP),
            _toAsset,
            _amountIn,
            bytes("")
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapOut(
            IUniswapV2Router02(CAMELOT_ROUTER),
            IUniswapV2Pair(WETH_ARB_LP),
            _amountIn,
            _toAsset,
            minToToken,
            bytes("")
        );
    }
}
