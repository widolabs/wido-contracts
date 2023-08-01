// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../contracts/core/zapper/WidoZapperUniswapV2.sol";
import "../../shared/MainnetForkTest.sol";

contract WidoZapperUniswapV2Test is MainnetForkTest {
    using SafeMath for uint256;

    WidoZapperUniswapV2 zapper;

    address constant UNI_ROUTER = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address constant USDC_WETH_LP = address(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperUniswapV2();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");
        vm.label(USDC_WETH_LP, "USDC_WETH_LP");
    }

    function test_zapUSDCForLP() public {

        /** Arrange */

        uint256 amount = 150_000_000;
        address fromAsset = USDC;
        address toAsset = USDC_WETH_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLe(IERC20(USDC).balanceOf(address(zapper)), 2, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapWETHForLP() public {

        /** Arrange */

        uint256 amount = 0.5 ether;
        address fromAsset = WETH;
        address toAsset = USDC_WETH_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLe(IERC20(USDC).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 2, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForUSDC() public {

        /** Arrange */

        _zapIn(zapper, USDC, 150_000_000);

        address fromAsset = USDC_WETH_LP;
        address toAsset = USDC;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLe(IERC20(USDC).balanceOf(address(zapper)), 2, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForWETH() public {

        /** Arrange */

        _zapIn(zapper, WETH, 0.5 ether);

        address fromAsset = USDC_WETH_LP;
        address toAsset = WETH;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLe(IERC20(USDC).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 2, "Dust");

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_revertWhen_zapWETHForLP_HasHighSlippage() public {

        /** Arrange */

        uint256 amount = 0.5 ether;
        address fromAsset = WETH;
        deal(fromAsset, user1, amount);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(USDC_WETH_LP),
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
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(USDC_WETH_LP),
            fromAsset,
            user1,
            amount,
            minToToken,
            bytes("")
        );
    }

    function test_revertWhen_zapWETHForLP_NoApproval() public {

        /** Arrange */

        uint256 amount = 0.5 ether;
        address fromAsset = WETH;
        deal(fromAsset, user1, amount);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(USDC_WETH_LP),
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
            IUniswapV2Pair(USDC_WETH_LP),
            fromAsset,
            user1,
            amount,
            minToToken,
            bytes("")
        );
    }

    function test_revertWhen_zapLPForWETH_NoBalance() public {

        /** Arrange */

        address fromAsset = USDC_WETH_LP;
        address toAsset = WETH;
        uint256 amount = 0.1 ether;

        uint256 minToToken = zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(USDC_WETH_LP),
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
            IUniswapV2Pair(USDC_WETH_LP),
            amount,
            toAsset,
            minToToken,
            bytes("")
        );
    }

    function test_revertWhen_notEnoughLPSupply() public {

        /** Arrange */

        address toAsset = WETH;
        uint256 amount = 10 ether;

        /** Act & Assert */

        vm.expectRevert();

        zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(USDC_WETH_LP),
            toAsset,
            amount,
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
            IUniswapV2Pair(USDC_WETH_LP),
            _fromAsset,
            _amountIn,
            bytes("")
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(USDC_WETH_LP),
            _fromAsset,
            user1,
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
            IUniswapV2Pair(USDC_WETH_LP),
            _toAsset,
            _amountIn,
            bytes("")
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(USDC_WETH_LP),
            _amountIn,
            _toAsset,
            minToToken,
            bytes("")
        );
    }
}
