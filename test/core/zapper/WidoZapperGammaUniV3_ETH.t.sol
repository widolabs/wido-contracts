// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../shared/MainnetForkTest.sol";
import "../../../contracts/core/zapper/WidoZapperGammaUniV3.sol";

/**
 This test fails sometimes for `Price change Overflow`
 It ia because they keep a TWAP and check against it.
*/
contract WidoZapperGamma_UniV3_ETH_Test is MainnetForkTest {
    using SafeMath for uint256;

    WidoZapperGammaUniV3 zapper;

    address constant UNI_ROUTER = address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);

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

        zapper = new WidoZapperGammaUniV3();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");

        pools.push(Pool(address(0xA9782a2C9C3Fb83937f14cDfAc9a6d23946C9255), 50e6, 1e18)); // USDC-WETH
        pools.push(Pool(address(0xa8076aE31e4B6c64D07b1Ed27889924a962a70d3), 1e18, 1e18)); // rETH-WETH
        pools.push(Pool(address(0x35aBccd8e577607275647edAb08C537fa32CC65E), 1e8, 1e18)); // WBTC-WETH
        pools.push(Pool(address(0xe1ae05518a67EBe7e1E08e3B22D905d6c05b6C0F), 10e18, 50e6)); // H20-USDC
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
        WidoZapperGammaUniV3 _zapper,
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
        .mul(985)
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
        WidoZapperGammaUniV3 _zapper,
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
        .mul(985)
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
