// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../shared/PolygonForkTest.sol";
import "../../../contracts/core/zapper/WidoZapperGamma.sol";

contract WidoZapperGammaTest is PolygonForkTest {
    using SafeMath for uint256;

    WidoZapperGamma zapper;

    address constant UNI_ROUTER = address(0xf5b509bB0909a69B1c207E495f687a596C168E12);
    address constant WMATIC_QUICK_LP = address(0x7f09bD2801A7b795dF29C273C4afbB0Ff15E2D63);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperGamma();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");
        vm.label(WMATIC_QUICK_LP, "WMATIC_QUICK_LP");
        vm.label(address(0x9F1A8cAF3C8e94e43aa64922d67dFf4dc3e88A42), "ALGEBRA_POOL");
        vm.label(address(0xe0A61107E250f8B5B24bf272baBFCf638569830C), "UNI_PROXY");
    }

    function test_zapWMATICForLP() public {
        /** Arrange */

        uint256 amount = 5e18;
        address fromAsset = WMATIC;
        address toAsset = WMATIC_QUICK_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);


        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapQUICKForLP() public {
        /** Arrange */

        uint256 amount = 50e18;
        address fromAsset = QUICK;
        address toAsset = WMATIC_QUICK_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);


        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForWMATIC() public {
        /** Arrange */

        _zapIn(zapper, WMATIC, 150e18);

        address fromAsset = WMATIC_QUICK_LP;
        address toAsset = WMATIC;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_zapLPForQUICK() public {
        /** Arrange */

        _zapIn(zapper, QUICK, 150e18);

        address fromAsset = WMATIC_QUICK_LP;
        address toAsset = QUICK;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        assertGt(IERC20(fromAsset).balanceOf(user1), 0, "From balance incorrect");

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function test_revertWhen_zapWMATICForLP_HasHighSlippage() public {
        /** Arrange */

        uint256 amount = 5 ether;
        address fromAsset = WMATIC;
        deal(fromAsset, user1, amount);

        uint256[] memory inMin = new uint256[](4);
        inMin[0] = 0;
        inMin[1] = 0;
        inMin[2] = 0;
        inMin[3] = 0;

        bytes memory data = abi.encode(inMin);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WMATIC_QUICK_LP),
            fromAsset,
            amount,
            data
        )
        .mul(1100)
        .div(1000);

        vm.startPrank(user1);

        IERC20(fromAsset).approve(address(zapper), amount);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WMATIC_QUICK_LP),
            fromAsset,
            amount,
            minToToken,
            data
        );
    }

    function test_revertWhen_zapWMATICForLP_NoApproval() public {
        /** Arrange */

        uint256 amount = 0.5 ether;
        address fromAsset = WMATIC;
        deal(fromAsset, user1, amount);

        uint256[] memory inMin = new uint256[](4);
        inMin[0] = 0;
        inMin[1] = 0;
        inMin[2] = 0;
        inMin[3] = 0;

        bytes memory data = abi.encode(inMin);

        uint256 minToToken = zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WMATIC_QUICK_LP),
            fromAsset,
            amount,
            data
        )
        .mul(998)
        .div(1000);

        vm.startPrank(user1);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WMATIC_QUICK_LP),
            fromAsset,
            amount,
            minToToken,
            data
        );
    }

    function test_revertWhen_zapLPForWMATIC_NoBalance() public {
        /** Arrange */

        address fromAsset = WMATIC_QUICK_LP;
        address toAsset = WMATIC;
        uint256 amount = 5 ether;

        uint256[] memory inMin = new uint256[](4);
        inMin[0] = 0;
        inMin[1] = 0;
        inMin[2] = 0;
        inMin[3] = 0;

        bytes memory data = abi.encode(inMin);

        uint256 minToToken = zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WMATIC_QUICK_LP),
            toAsset,
            amount,
            data
        )
        .mul(998)
        .div(1000);

        vm.startPrank(user1);

        IERC20(fromAsset).approve(address(zapper), amount);

        /** Act & Assert */

        vm.expectRevert();

        zapper.zapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WMATIC_QUICK_LP),
            amount,
            toAsset,
            minToToken,
            data
        );
    }

    function _zapIn(
        WidoZapperGamma _zapper,
        address _fromAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        deal(_fromAsset, user1, _amountIn);
        vm.startPrank(user1);

        uint256[] memory inMin = new uint256[](4);
        inMin[0] = 0;
        inMin[1] = 0;
        inMin[2] = 0;
        inMin[3] = 0;

        bytes memory data = abi.encode(inMin);

        minToToken = _zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WMATIC_QUICK_LP),
            _fromAsset,
            _amountIn,
            data
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WMATIC_QUICK_LP),
            _fromAsset,
            _amountIn,
            minToToken,
            data
        );
    }

    function _zapOut(
        WidoZapperGamma _zapper,
        address _fromAsset,
        address _toAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){

        uint256[] memory inMin = new uint256[](4);
        inMin[0] = 0;
        inMin[1] = 0;
        inMin[2] = 0;
        inMin[3] = 0;

        bytes memory data = abi.encode(inMin);

        minToToken = _zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WMATIC_QUICK_LP),
            _toAsset,
            _amountIn,
            data
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WMATIC_QUICK_LP),
            _amountIn,
            _toAsset,
            minToToken,
            data
        );
    }
}
