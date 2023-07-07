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

    address constant UNI_ROUTER = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
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

        console2.log(finalFromBalance);
        console2.log(finalToBalance);

        console2.log(IERC20(WMATIC).balanceOf(address(zapper)));
        console2.log(IERC20(QUICK).balanceOf(address(zapper)));

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");
    }

    function _zapIn(
        WidoZapperGamma _zapper,
        address _fromAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        deal(_fromAsset, user1, _amountIn);
        vm.startPrank(user1);

        address swapRouter = address(0xf5b509bB0909a69B1c207E495f687a596C168E12);
        uint256[] memory inMin = new uint256[](4);
        inMin[0] = 0;
        inMin[1] = 0;
        inMin[2] = 0;
        inMin[3] = 0;

        bytes memory data = abi.encode(swapRouter, inMin);

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
}
