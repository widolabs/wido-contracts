// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../contracts/core/zapper/WidoZapperUniswapV3.sol";
import "../../shared/ArbitrumForkTest.sol";
import "../../shared/MainnetForkTest.sol";

contract WidoZapperUniswapV3_WETH_USDC_Test is MainnetForkTest {
    using SafeMath for uint256;

    WidoZapperUniswapV3 zapper;

    address constant UNI_ROUTER = address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address constant UNI_POS_MANAGER = address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    address constant WETH_USDC_LP = address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperUniswapV3();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");
        vm.label(UNI_POS_MANAGER, "UNI_POS_MANAGER");
        vm.label(WETH_USDC_LP, "WETH_USDC_LP");
    }

    function test_zapWETHForLP() public {
        /** Arrange */

        uint256 amount = 50e18;
        address fromAsset = WETH;

        /** Act */

        _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        assertEq(finalFromBalance, 0, "From balance incorrect");

        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        assertNotEq(tokenId, 0, "To balance incorrect");

        assertLe(IERC20(USDC).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapUSDCForLP() public {
        /** Arrange */

        uint256 amount = 50e6;
        address fromAsset = USDC;

        /** Act */

        _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        assertEq(finalFromBalance, 0, "From balance incorrect");

        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        assertNotEq(tokenId, 0, "To balance incorrect");

        assertLe(IERC20(USDC).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapLPForWETH() public {
        /** Arrange */

        _zapIn(zapper, WETH, 1e18);

        address toAsset = WETH;
        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        (, , , , , , , uint128 liquidity, , , , ) = INonfungiblePositionManager(UNI_POS_MANAGER).positions(tokenId);

        /** Act */

        uint256 minToToken = _zapOut(zapper, toAsset, tokenId, uint256(liquidity));

        /** Assert */

        vm.expectRevert();
        INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);

        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(USDC).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");
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

        bytes memory data = abi.encode(lowerTick, upperTick);

        minToToken = _zapper.calcMinToAmountForZapIn(
            ISwapRouter02(UNI_ROUTER),
            IUniswapV3Pool(WETH_USDC_LP),
            INonfungiblePositionManager(UNI_POS_MANAGER),
            _fromAsset,
            _amountIn,
            data
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            ISwapRouter02(UNI_ROUTER),
            IUniswapV3Pool(WETH_USDC_LP),
            INonfungiblePositionManager(UNI_POS_MANAGER),
            _fromAsset,
            user1,
            _amountIn,
            minToToken,
            data
        );
    }

    function _zapOut(
        WidoZapperUniswapV3 _zapper,
        address _toAsset,
        uint256 _tokenId,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        int24 lowerTick = 1000;
        int24 upperTick = 1200;

        bytes memory data = abi.encode(lowerTick, upperTick);

        minToToken = _zapper.calcMinToAmountForZapOut(
            ISwapRouter02(UNI_ROUTER),
            IUniswapV3Pool(WETH_USDC_LP),
            INonfungiblePositionManager(UNI_POS_MANAGER),
            _toAsset,
            _amountIn,
            data
        )
        .mul(998)
        .div(1000);

        INonfungiblePositionManager(UNI_POS_MANAGER).approve(address(_zapper), _tokenId);

        _zapper.zapOut(
            ISwapRouter02(UNI_ROUTER),
            IUniswapV3Pool(WETH_USDC_LP),
            INonfungiblePositionManager(UNI_POS_MANAGER),
            _tokenId,
            _toAsset,
            minToToken,
            data
        );
    }
}
