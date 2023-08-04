// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../contracts/core/zapper/WidoZapperUniswapV3.sol";
import "../../shared/ArbitrumForkTest.sol";
import "../../shared/MainnetForkTest.sol";

contract WidoZapperUniswapV3_SPA_plsSPA_Test is ArbitrumForkTest {
    using SafeMath for uint256;

    WidoZapperUniswapV3 zapper;

    address constant UNI_ROUTER = address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address constant UNI_POS_MANAGER = address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    address constant SPA_plsSPA_LP = address(0x03344b394cCdB3C36DDd134F4962d2fA97e3e714);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperUniswapV3();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");
        vm.label(UNI_POS_MANAGER, "UNI_POS_MANAGER");
        vm.label(SPA_plsSPA_LP, "SPA_plsSPA_LP");
    }

    function test_zapSPAForLP() public {
        /** Arrange */

        uint256 amount = 50e18;
        address fromAsset = SPA;

        /** Act */

        _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        assertEq(finalFromBalance, 0, "From balance incorrect");

        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        assertNotEq(tokenId, 0, "To balance incorrect");

        assertLe(IERC20(plsSPA).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(SPA).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapplsSPAForLP() public {
        /** Arrange */

        uint256 amount = 50e18;
        address fromAsset = plsSPA;

        /** Act */

        _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        assertEq(finalFromBalance, 0, "From balance incorrect");

        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        assertNotEq(tokenId, 0, "To balance incorrect");

        assertLe(IERC20(plsSPA).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(SPA).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapLPForSPA() public {
        /** Arrange */

        _zapIn(zapper, SPA, 1e18);

        address toAsset = SPA;
        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        (, , , , , , , uint128 liquidity, , , , ) = INonfungiblePositionManager(UNI_POS_MANAGER).positions(tokenId);

        /** Act */

        uint256 minToToken = _zapOut(zapper, toAsset, tokenId, uint256(liquidity));

        /** Assert */

        vm.expectRevert();
        INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);

        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(plsSPA).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(SPA).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapLPForplsSPA() public {
        /** Arrange */

        _zapIn(zapper, plsSPA, 10e6);

        address toAsset = plsSPA;
        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        (, , , , , , , uint128 liquidity, , , , ) = INonfungiblePositionManager(UNI_POS_MANAGER).positions(tokenId);

        /** Act */

        uint256 minToToken = _zapOut(zapper, toAsset, tokenId, uint256(liquidity));

        /** Assert */

        vm.expectRevert();
        INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);

        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(plsSPA).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(SPA).balanceOf(address(zapper)), 0, "Dust");
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

        minToToken = uint256(_zapper.calcMinToAmountForZapIn(
            IUniswapV3Pool(SPA_plsSPA_LP),
            _fromAsset,
            _amountIn,
            lowerTick,
            upperTick
        ))
        .mul(998)
        .div(1000);

        WidoZapperUniswapV3.ZapInOrder memory zap = WidoZapperUniswapV3.ZapInOrder({
            pool: IUniswapV3Pool(SPA_plsSPA_LP),
            fromToken: _fromAsset,
            amount: _amountIn,
            lowerTick: lowerTick,
            upperTick: upperTick,
            minToToken: minToToken,
            recipient: user1
        });

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            ISwapRouter02(UNI_ROUTER),
            INonfungiblePositionManager(UNI_POS_MANAGER),
            zap
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

        minToToken = uint256(_zapper.calcMinToAmountForZapOut(
            IUniswapV3Pool(SPA_plsSPA_LP),
            _toAsset,
            uint128(_amountIn),
            lowerTick,
            upperTick
        ))
        .mul(998)
        .div(1000);

        INonfungiblePositionManager(UNI_POS_MANAGER).approve(address(_zapper), _tokenId);

        WidoZapperUniswapV3.ZapOutOrder memory zap = WidoZapperUniswapV3.ZapOutOrder({
            pool: IUniswapV3Pool(SPA_plsSPA_LP),
            toToken: _toAsset,
            tokenId: _tokenId,
            minToToken: minToToken
        });


        _zapper.zapOut(
            ISwapRouter02(UNI_ROUTER),
            INonfungiblePositionManager(UNI_POS_MANAGER),
            zap
        );
    }
}
