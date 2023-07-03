// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../shared/OptimismForkTest.sol";
import "../../../contracts/core/zapper/WidoZapperVelodromeV2.sol";

contract WidoZapperVelodromeV2Test is OptimismForkTest {
    using SafeMath for uint256;

    WidoZapperVelodromeV2 zapper;

    address constant VELO_V2_ROUTER = address(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);
    address constant WTBT_USDC_LP = address(0x5e6E17F745fF620E87324b7c6ec672B5743BD0B4);
    address constant WTBT = address(0xdb4eA87fF83eB1c80b8976FC47731Da6a31D35e5);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperVelodromeV2();
        vm.label(address(zapper), "Zapper");

        vm.label(VELO_V2_ROUTER, "VELO_V2_ROUTER");
        vm.label(WTBT_USDC_LP, "WTBT_USDC_LP");
        vm.label(WTBT, "WTBT");
    }

    function test_zapUSDCForLP() public {
        /** Arrange */

        uint256 amount = 50_000_000;
        address fromAsset = USDC;
        address toAsset = WTBT_USDC_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapWTBTForLP() public {
        /** Arrange */

        uint256 amount = 1e18;
        address fromAsset = WTBT;
        address toAsset = WTBT_USDC_LP;

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

        address fromAsset = WTBT_USDC_LP;
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

    function test_zapLPForWTBT() public {
        /** Arrange */

        _zapIn(zapper, WTBT, 1e18);

        address fromAsset = WTBT_USDC_LP;
        address toAsset = WTBT;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_revertWhen_zapWTBTForLP_HasHighSlippage() public {
        /** Arrange */

        uint256 amount = 200_000;
        address fromAsset = WTBT;
        deal(fromAsset, user1, amount);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(WTBT_USDC_LP),
            fromAsset,
            amount,
            abi.encode(false)
        )
        .mul(1001)
        .div(1000);

        vm.startPrank(user1);

        IERC20(fromAsset).approve(address(zapper), amount);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapIn(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(WTBT_USDC_LP),
            fromAsset,
            amount,
            minToToken,
            abi.encode(false)
        );
    }

    function test_revertWhen_zapWTBTForLP_NoApproval() public {
        /** Arrange */

        uint256 amount = 200_000;
        address fromAsset = WTBT;
        deal(fromAsset, user1, amount);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(WTBT_USDC_LP),
            fromAsset,
            amount,
            abi.encode(false)
        )
        .mul(998)
        .div(1000);

        vm.startPrank(user1);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapIn(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(WTBT_USDC_LP),
            fromAsset,
            amount,
            minToToken,
            abi.encode(false)
        );
    }

    function test_revertWhen_zapLPForWTBT_NoBalance() public {
        /** Arrange */

        address fromAsset = WTBT_USDC_LP;
        address toAsset = WTBT;
        uint256 amount = 1 ether;

        uint256 minToToken = zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(WTBT_USDC_LP),
            toAsset,
            amount,
            abi.encode(false)
        )
        .mul(998)
        .div(1000);

        vm.startPrank(user1);

        IERC20(fromAsset).approve(address(zapper), amount);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapOut(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(WTBT_USDC_LP),
            amount,
            toAsset,
            minToToken,
            abi.encode(false)
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
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(WTBT_USDC_LP),
            _fromAsset,
            _amountIn,
            abi.encode(false)
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(WTBT_USDC_LP),
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
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(WTBT_USDC_LP),
            _toAsset,
            _amountIn,
            abi.encode(false)
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapOut(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(WTBT_USDC_LP),
            _amountIn,
            _toAsset,
            minToToken,
            abi.encode(false)
        );
    }
}
