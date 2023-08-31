// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../contracts/core/zapper/WidoZapperUniswapV3.sol";
import "../../shared/MainnetForkTest.sol";

contract WidoZapperUniswapV3_Test is MainnetForkTest {
    using SafeMath for uint256;

    WidoZapperUniswapV3 zapper;

    address constant UNI_ROUTER = address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address constant UNI_POS_MANAGER = address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    struct Pool {
        address pool_address;
        uint256 amount0;
        uint256 amount1;
    }

    Pool[] pools;

    function _getPool(uint8 _p) internal view returns (Pool memory) {
        vm.assume(_p < pools.length);
        return pools[_p];
    }

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperUniswapV3();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");
        vm.label(UNI_POS_MANAGER, "UNI_POS_MANAGER");

        pools.push(Pool(address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640), 50e6, 2e18)); // USDC-WETH
    }

    function test_zapToken0ForLP(uint8 _p) public {
        /** Arrange */

        Pool memory pool = _getPool(_p);

        address token0 = IUniswapV3Pool(pool.pool_address).token0();
        address token1 = IUniswapV3Pool(pool.pool_address).token1();

        uint256 amount = pool.amount0;

        /** Act */

        _zapIn(pool.pool_address, zapper, token0, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(token0).balanceOf(user1);
        assertEq(finalFromBalance, 0, "From balance incorrect");

        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        assertNotEq(tokenId, 0, "To balance incorrect");

        assertLe(IERC20(token0).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(token1).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapToken1ForLP(uint8 _p) public {
        /** Arrange */

        Pool memory pool = _getPool(_p);

        address token0 = IUniswapV3Pool(pool.pool_address).token0();
        address token1 = IUniswapV3Pool(pool.pool_address).token1();

        uint256 amount = pool.amount1;

        /** Act */

        _zapIn(pool.pool_address, zapper, token1, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(token1).balanceOf(user1);
        assertEq(finalFromBalance, 0, "From balance incorrect");

        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        assertNotEq(tokenId, 0, "To balance incorrect");

        assertLe(IERC20(token0).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(token1).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapLPForToken0(uint8 _p) public {
        /** Arrange */

        Pool memory pool = _getPool(_p);

        address token0 = IUniswapV3Pool(pool.pool_address).token0();
        address token1 = IUniswapV3Pool(pool.pool_address).token1();

        _zapIn(pool.pool_address, zapper, token0, pool.amount0);

        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        (, , , , , , , uint128 liquidity, , , , ) = INonfungiblePositionManager(UNI_POS_MANAGER).positions(tokenId);

        /** Act */

        uint256 minToToken = _zapOut(pool.pool_address, zapper, token0, tokenId, uint256(liquidity));

        /** Assert */

        vm.expectRevert();
        INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);

        uint256 finalToBalance = IERC20(token0).balanceOf(user1);
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(token0).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(token1).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapLPForToken1(uint8 _p) public {
        /** Arrange */

        Pool memory pool = _getPool(_p);

        address token0 = IUniswapV3Pool(pool.pool_address).token0();
        address token1 = IUniswapV3Pool(pool.pool_address).token1();

        _zapIn(pool.pool_address, zapper, token1, pool.amount1);

        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        (, , , , , , , uint128 liquidity, , , , ) = INonfungiblePositionManager(UNI_POS_MANAGER).positions(tokenId);

        /** Act */

        uint256 minToToken = _zapOut(pool.pool_address, zapper, token1, tokenId, uint256(liquidity));

        /** Assert */

        vm.expectRevert();
        INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);

        uint256 finalToBalance = IERC20(token1).balanceOf(user1);
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(token0).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(token1).balanceOf(address(zapper)), 0, "Dust");
    }

    function _zapIn(
        address pool,
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
            IUniswapV3Pool(pool),
            _fromAsset,
            _amountIn,
            lowerTick,
            upperTick
        ))
        .mul(998)
        .div(1000);

        WidoZapperUniswapV3.ZapInOrder memory zap = WidoZapperUniswapV3.ZapInOrder({
            pool: IUniswapV3Pool(pool),
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
        address pool,
        WidoZapperUniswapV3 _zapper,
        address _toAsset,
        uint256 _tokenId,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        int24 lowerTick = 1000;
        int24 upperTick = 1200;

        bytes memory data = abi.encode(lowerTick, upperTick);

        minToToken = uint256(_zapper.calcMinToAmountForZapOut(
            IUniswapV3Pool(pool),
            _toAsset,
            uint128(_amountIn),
            lowerTick,
            upperTick
        ))
        .mul(998)
        .div(1000);

        INonfungiblePositionManager(UNI_POS_MANAGER).approve(address(_zapper), _tokenId);

        WidoZapperUniswapV3.ZapOutOrder memory zap = WidoZapperUniswapV3.ZapOutOrder({
            pool: IUniswapV3Pool(pool),
            toToken: _toAsset,
            tokenId: _tokenId,
            minToToken: minToToken,
            recipient: user1
        });


        _zapper.zapOut(
            ISwapRouter02(UNI_ROUTER),
            INonfungiblePositionManager(UNI_POS_MANAGER),
            zap
        );
    }
}
