// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../shared/PolygonForkTest.sol";
import "../../../contracts/core/zapper/WidoZapperGammaRetro.sol";

/**
 This test fails sometimes for `Price change Overflow`
 It ia because they keep a TWAP and check against it.
*/
contract WidoZapperGamma_Retro_Test is PolygonForkTest {
    using SafeMath for uint256;

    WidoZapperGammaRetro zapper;

    address constant UNI_ROUTER = address(0x1891783cb3497Fdad1F25C933225243c2c7c4102);

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

        zapper = new WidoZapperGammaRetro();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");


        pools.push(Pool(address(0xe7806B5ba13d4B2Ab3EaB3061cB31d4a4F3390Aa), 150e18, 5e16)); // WMATIC-WETH
        pools.push(Pool(address(0x7b4a08284A93c424c9A1Fd99D04Ee4e3c64B041D), 150e18, 150e6)); // WMATIC-USDT
        pools.push(Pool(address(0xFb730DeD9f9369Df68F4a67633B7B3bE37094EE8), 50e6, 1e18)); // USDC-RETRO
    }

    function test_zapToken0ForLP(uint8 _p) public {
        /** Arrange */

        Pool memory pool = _getPool(_p);

        address token0 = IUniswapV2Pair(pool.pool_address).token0();
        address token1 = IUniswapV2Pair(pool.pool_address).token1();

        uint256 amount = pool.amount0;

        /** Act */

        uint256 minToToken = _zapIn(pool.pool_address, zapper, token0, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(token0).balanceOf(user1);
        uint256 finalToBalance = IERC20(pool.pool_address).balanceOf(user1);

        assertLt(finalFromBalance, amount, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(token0).balanceOf(address(zapper)), 0, "Dust token0");
        assertLe(IERC20(token1).balanceOf(address(zapper)), 0, "Dust token1");
    }

    function test_zapToken1ForLP(uint8 _p) public {
        /** Arrange */

        Pool memory pool = _getPool(_p);

        address token0 = IUniswapV2Pair(pool.pool_address).token0();
        address token1 = IUniswapV2Pair(pool.pool_address).token1();

        uint256 amount = pool.amount1;

        /** Act */

        uint256 minToToken = _zapIn(pool.pool_address, zapper, token1, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(token1).balanceOf(user1);
        uint256 finalToBalance = IERC20(pool.pool_address).balanceOf(user1);

        assertLt(finalFromBalance, amount, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(token0).balanceOf(address(zapper)), 0, "Dust token0");
        assertLe(IERC20(token1).balanceOf(address(zapper)), 0, "Dust token1");
    }

    function test_zapLPForToken0(uint8 _p) public {
        /** Arrange */

        Pool memory pool = _getPool(_p);

        address token0 = IUniswapV2Pair(pool.pool_address).token0();
        address token1 = IUniswapV2Pair(pool.pool_address).token1();

        _zapIn(pool.pool_address, zapper, token0, pool.amount0);

        uint256 amount = IERC20(pool.pool_address).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, pool.pool_address, token0, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(pool.pool_address).balanceOf(user1);
        uint256 finalToBalance = IERC20(token0).balanceOf(user1);

        assertLt(finalFromBalance, amount, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(token0).balanceOf(address(zapper)), 0, "Dust token0");
        assertLe(IERC20(token1).balanceOf(address(zapper)), 0, "Dust token1");
    }

    function test_zapLPForToken1(uint8 _p) public {
        /** Arrange */

        Pool memory pool = _getPool(_p);

        address token0 = IUniswapV2Pair(pool.pool_address).token0();
        address token1 = IUniswapV2Pair(pool.pool_address).token1();

        _zapIn(pool.pool_address, zapper, token1, pool.amount1);

        uint256 amount = IERC20(pool.pool_address).balanceOf(user1);

        assertGt(IERC20(pool.pool_address).balanceOf(user1), 0, "From balance incorrect");

        /** Act */

        uint256 minToToken = _zapOut(zapper, pool.pool_address, token1, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(pool.pool_address).balanceOf(user1);
        uint256 finalToBalance = IERC20(token1).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(token0).balanceOf(address(zapper)), 0, "Dust token0");
        assertLe(IERC20(token1).balanceOf(address(zapper)), 0, "Dust token1");
    }

    function _zapIn(
        address pool,
        WidoZapperGammaRetro _zapper,
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
            IUniswapV2Pair(pool),
            _fromAsset,
            _amountIn,
            data
        )
        .mul(989)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(pool),
            _fromAsset,
            user1,
            _amountIn,
            minToToken,
            data
        );
    }

    function _zapOut(
        WidoZapperGammaRetro _zapper,
        address _fromAsset,
        address _toAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken) {

        uint256[] memory inMin = new uint256[](4);
        inMin[0] = 0;
        inMin[1] = 0;
        inMin[2] = 0;
        inMin[3] = 0;

        bytes memory data = abi.encode(inMin);

        minToToken = _zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(_fromAsset),
            _toAsset,
            _amountIn,
            data
        )
        .mul(989)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(_fromAsset),
            _amountIn,
            _toAsset,
            minToToken,
            data
        );
    }
}
