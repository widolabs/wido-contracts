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
    address constant WETH_ARB_LP = address(0x913398d79438e8D709211cFC3DC8566F6C67e1A8);
    address constant GMX = address(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a);
    address constant USDCe = address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperCamelot();
        vm.label(address(zapper), "Zapper");

        vm.label(CAMELOT_ROUTER, "CAMELOT_ROUTER");
        vm.label(WETH_ARB_LP, "WETH_ARB_LP");
    }

    function test_zapGMXForLP() public {
        /** Arrange */

        uint256 amount = 150e18;
        address fromAsset = GMX;
        address toAsset = WETH_ARB_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLe(IERC20(GMX).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(USDCe).balanceOf(address(zapper)), 3, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapUSDCForLP() public {
        /** Arrange */

        uint256 amount = 13704e6;
        address fromAsset = USDCe;
        address toAsset = WETH_ARB_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLe(IERC20(GMX).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(USDCe).balanceOf(address(zapper)), 3, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForGMX() public {
        /** Arrange */

        _zapIn(zapper, GMX, 15e18);

        address fromAsset = WETH_ARB_LP;
        address toAsset = GMX;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLe(IERC20(GMX).balanceOf(address(zapper)), 3, "Dust");
        assertLe(IERC20(USDCe).balanceOf(address(zapper)), 0, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForUSDC() public {
        /** Arrange */

        _zapIn(zapper, USDCe, 150e6);

        address fromAsset = WETH_ARB_LP;
        address toAsset = USDCe;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLe(IERC20(GMX).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(USDCe).balanceOf(address(zapper)), 3, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_revertWhen_zapARBForLP_HasHighSlippage() public {
        /** Arrange */

        uint256 amount = 150e18;
        address fromAsset = GMX;
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

        uint256 amount = 150e18;
        address fromAsset = GMX;
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
        address toAsset = GMX;
        uint256 amount = 0.01 ether;

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
        WidoZapperCamelot _zapper,
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
        .mul(995)
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
        WidoZapperCamelot _zapper,
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
        .mul(995)
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
