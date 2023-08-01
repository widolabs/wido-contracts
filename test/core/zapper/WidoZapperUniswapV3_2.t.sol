// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../contracts/core/zapper/WidoZapperUniswapV3.sol";
import "../../shared/ArbitrumForkTest.sol";
import "../../shared/MainnetForkTest.sol";

contract WidoZapperUniswapV3Test is MainnetForkTest {
    using SafeMath for uint256;

    WidoZapperUniswapV3 zapper;

    address constant UNI_ROUTER = address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address constant UNI_POS_MANAGER = address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    address constant ARB_USDs_LP = address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperUniswapV3();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");
        vm.label(UNI_POS_MANAGER, "UNI_POS_MANAGER");
        vm.label(ARB_USDs_LP, "ARB_USDs_LP");
    }

    function test_zapARBForLP() public {
        /** Arrange */

        uint256 amount = 50e6;
        address fromAsset = USDC;
        address toAsset = ARB_USDs_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);


        assertEq(finalFromBalance, 0, "From balance incorrect");
    }

    function test_zapUSDsForLP() public {
        /** Arrange */

        uint256 amount = 50e6;
        address fromAsset = USDC;
        address toAsset = ARB_USDs_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);


        assertEq(finalFromBalance, 0, "From balance incorrect");
    }

    function _zapIn(
        WidoZapperUniswapV3 _zapper,
        address _fromAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        deal(_fromAsset, user1, _amountIn);
        vm.startPrank(user1);

        int24 lowerTick = 1000;
        int24 upperTick = 1200;

        bytes memory data = abi.encode(lowerTick, upperTick, UNI_POS_MANAGER);

        minToToken = _zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(ARB_USDs_LP),
            _fromAsset,
            _amountIn,
            data
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(ARB_USDs_LP),
            _fromAsset,
            user1,
            _amountIn,
            minToToken,
            data
        );
    }

    function _zapOut(
        WidoZapperUniswapV3 _zapper,
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
            IUniswapV2Pair(ARB_USDs_LP),
            _toAsset,
            _amountIn,
            data
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(ARB_USDs_LP),
            _amountIn,
            _toAsset,
            minToToken,
            data
        );
    }
}
