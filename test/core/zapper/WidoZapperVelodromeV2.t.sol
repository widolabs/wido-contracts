// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../shared/OptimismForkTest.sol";
import "../../../contracts/core/zapper/WidoZapperVelodromeV2.sol";

contract WidoZapperVelodromeV2_Test is OptimismForkTest {
    using SafeMath for uint256;

    WidoZapperVelodromeV2 zapper;

    address constant VELO_V2_ROUTER = address(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);

    struct Pool {
        address pool_address;
        uint256 amount0;
        uint256 amount1;
        bool stable;
    }

    Pool[] pools;

    function _getPool(uint8 _p) internal view returns (Pool memory) {
        vm.assume(_p < pools.length);
        return pools[_p];
    }

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperVelodromeV2();
        vm.label(address(zapper), "Zapper");

        vm.label(VELO_V2_ROUTER, "VELO_V2_ROUTER");

        pools.push(Pool(address(0xB720FBC32d60BB6dcc955Be86b98D8fD3c4bA645), 5e6, 1e18, true)); // USDC-DOLA
        pools.push(Pool(address(0x1f8b46abe1EAbF5A60CbBB5Fb2e4a6A46fA0b6e6), 5e18, 8e18, true)); // FRAX-DOLA
        pools.push(Pool(address(0x5e6E17F745fF620E87324b7c6ec672B5743BD0B4), 50e6, 1e18, false)); // USDC-WTBT
    }

    function test_zapToken0ForLP(uint8 _p) public {
        /** Arrange */

        Pool memory pool = _getPool(_p);

        address token0 = IUniswapV2Pair(pool.pool_address).token0();
        address token1 = IUniswapV2Pair(pool.pool_address).token1();

        uint256 amount = pool.amount0;

        /** Act */

        uint256 minToToken = _zapIn(pool.pool_address, zapper, token0, amount, pool.stable);

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

        uint256 minToToken = _zapIn(pool.pool_address, zapper, token1, amount, pool.stable);

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

        _zapIn(pool.pool_address, zapper, token0, pool.amount0, pool.stable);

        uint256 amount = IERC20(pool.pool_address).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, pool.pool_address, token0, amount, pool.stable);

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

        _zapIn(pool.pool_address, zapper, token1, pool.amount1, pool.stable);

        uint256 amount = IERC20(pool.pool_address).balanceOf(user1);

        assertGt(IERC20(pool.pool_address).balanceOf(user1), 0, "From balance incorrect");

        /** Act */

        uint256 minToToken = _zapOut(zapper, pool.pool_address, token1, amount, pool.stable);

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
        WidoZapperVelodromeV2 _zapper,
        address _fromAsset,
        uint256 _amountIn,
        bool stable
    ) internal returns (uint256 minToToken){
        deal(_fromAsset, user1, _amountIn);
        vm.startPrank(user1);

        bytes memory data = abi.encode(stable);

        minToToken = _zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(pool),
            _fromAsset,
            _amountIn,
            data
        )
        .mul(994)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(pool),
            _fromAsset,
            user1,
            _amountIn,
            minToToken,
            data
        );
    }

    function _zapOut(
        WidoZapperVelodromeV2 _zapper,
        address _fromAsset,
        address _toAsset,
        uint256 _amountIn,
        bool stable
    ) internal returns (uint256 minToToken){

        bytes memory data = abi.encode(stable);

        minToToken = _zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(_fromAsset),
            _toAsset,
            _amountIn,
            data
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapOut(
            IUniswapV2Router02(VELO_V2_ROUTER),
            IUniswapV2Pair(_fromAsset),
            _amountIn,
            _toAsset,
            minToToken,
            data
        );
    }
}
