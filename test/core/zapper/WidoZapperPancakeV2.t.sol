// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../contracts/core/zapper/WidoZapperUniswapV2.sol";
import "../../shared/MainnetForkTest.sol";
import "../../shared/BSCForkTest.sol";

contract WidoZapperPancakeV2Test is BSCForkTest {
    using SafeMath for uint256;

    WidoZapperUniswapV2 zapper;

    address constant UNI_ROUTER = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address constant USDC_WETH_LP = address(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperUniswapV2();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");
        vm.label(USDC_WETH_LP, "USDC_WETH_LP");
    }

    function test_zapUSDCForLP() public {

        /** Arrange */

        uint256 amount = 150e18;
        address fromAsset = WBNB;
        address toAsset = USDC_WETH_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(IERC20(WBNB).balanceOf(address(zapper)), 0, "Dust");
        assertEq(IERC20(BUSD).balanceOf(address(zapper)), 0, "Dust");

        assertLt(finalFromBalance, amount, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapWETHForLP() public {

        /** Arrange */

        uint256 amount = 150e18;
        address fromAsset = BUSD;
        address toAsset = USDC_WETH_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(IERC20(BUSD).balanceOf(address(zapper)), 0, "Dust");
        assertEq(IERC20(WBNB).balanceOf(address(zapper)), 0, "Dust");

        assertLt(finalFromBalance, amount, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForUSDC() public {

        /** Arrange */

        _zapIn(zapper, WBNB, 150e18);

        address fromAsset = USDC_WETH_LP;
        address toAsset = WBNB;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(IERC20(WBNB).balanceOf(address(zapper)), 0, "Dust");
        assertEq(IERC20(BUSD).balanceOf(address(zapper)), 0, "Dust");

        assertLt(finalFromBalance, amount, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForWETH() public {

        /** Arrange */

        _zapIn(zapper, BUSD, 150e18);

        address fromAsset = USDC_WETH_LP;
        address toAsset = BUSD;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(IERC20(BUSD).balanceOf(address(zapper)), 0, "Dust");
        assertEq(IERC20(WBNB).balanceOf(address(zapper)), 0, "Dust");

        assertLt(finalFromBalance, amount, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
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
