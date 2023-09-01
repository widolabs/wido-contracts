// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../contracts/core/zapper/WidoZapperUniswapV3.sol";
import "../../shared/ArbitrumForkTest.sol";

contract WidoZapperUniswapV3_Test is ArbitrumForkTest {
    using SafeMath for uint256;

    WidoZapperUniswapV3 zapper;

    address constant UNI_ROUTER = address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address constant UNI_POS_MANAGER = address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    enum Ticker {
        Low,
        Current,
        High
    }

    struct Pool {
        address pool_address;
        uint256 amount0;
        uint256 amount1;
        Ticker range;
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

        // plsSPA-SPA
        pools.push(Pool(address(0x03344b394cCdB3C36DDd134F4962d2fA97e3e714), 50e18, 50e18, Ticker.Low));
        pools.push(Pool(address(0x03344b394cCdB3C36DDd134F4962d2fA97e3e714), 50e18, 50e18, Ticker.Current));
        pools.push(Pool(address(0x03344b394cCdB3C36DDd134F4962d2fA97e3e714), 50e18, 50e18, Ticker.High));
        // USDs-USDC
        //pools.push(Pool(address(0x50450351517117Cb58189edBa6bbaD6284D45902), 50e18, 50e6, Ticker.Low));
        //pools.push(Pool(address(0x50450351517117Cb58189edBa6bbaD6284D45902), 50e18, 50e6, Ticker.Current));
        //pools.push(Pool(address(0x50450351517117Cb58189edBa6bbaD6284D45902), 50e18, 50e6, Ticker.High));
        // WETH-USDs
        //pools.push(Pool(address(0x5766DA927BCB6F60Cefdc559ea30DDD3A4C5Db0F), 50e18, 50e18, Ticker.Low));
        //pools.push(Pool(address(0x5766DA927BCB6F60Cefdc559ea30DDD3A4C5Db0F), 50e18, 50e18, Ticker.Current));
        //pools.push(Pool(address(0x5766DA927BCB6F60Cefdc559ea30DDD3A4C5Db0F), 50e18, 50e18, Ticker.High));
    }

    function test_zapToken0ForLP(uint8 _p) public {
        /** Arrange */

        Pool memory pool = _getPool(_p);

        address token0 = IUniswapV3Pool(pool.pool_address).token0();
        address token1 = IUniswapV3Pool(pool.pool_address).token1();

        uint256 amount = pool.amount0;

        /** Act */

        _zapIn(pool, zapper, token0, amount);

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

        _zapIn(pool, zapper, token1, amount);

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

        _zapIn(pool, zapper, token0, pool.amount0);

        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        (, , , , , , , uint128 liquidity, , , ,) = INonfungiblePositionManager(UNI_POS_MANAGER).positions(tokenId);

        /** Act */

        uint256 minToToken = _zapOut(pool, zapper, token0, tokenId, uint256(liquidity));

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

        _zapIn(pool, zapper, token1, pool.amount1);

        uint tokenId = INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);
        (, , , , , , , uint128 liquidity, , , ,) = INonfungiblePositionManager(UNI_POS_MANAGER).positions(tokenId);

        /** Act */

        uint256 minToToken = _zapOut(pool, zapper, token1, tokenId, uint256(liquidity));

        /** Assert */

        vm.expectRevert();
        INonfungiblePositionManager(UNI_POS_MANAGER).tokenOfOwnerByIndex(user1, 0);

        uint256 finalToBalance = IERC20(token1).balanceOf(user1);
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(token0).balanceOf(address(zapper)), 0, "Dust token0");
        assertLe(IERC20(token1).balanceOf(address(zapper)), 0, "Dust token1");
    }

    function _zapIn(
        Pool memory pool,
        WidoZapperUniswapV3 _zapper,
        address _fromAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        deal(_fromAsset, user1, _amountIn);
        vm.startPrank(user1);

        (int24 lowerTick, int24 upperTick) = tickers(pool.range, pool.pool_address);

        minToToken = uint256(_zapper.calcMinToAmountForZapIn(
            IUniswapV3Pool(pool.pool_address),
            _fromAsset,
            _amountIn,
            lowerTick,
            upperTick
        ))
        .mul(998)
        .div(1000);

        WidoZapperUniswapV3.ZapInOrder memory zap = WidoZapperUniswapV3.ZapInOrder({
            pool: IUniswapV3Pool(pool.pool_address),
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
        Pool memory pool,
        WidoZapperUniswapV3 _zapper,
        address _toAsset,
        uint256 _tokenId,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        (int24 lowerTick, int24 upperTick) = tickers(pool.range, pool.pool_address);

        minToToken = uint256(_zapper.calcMinToAmountForZapOut(
            IUniswapV3Pool(pool.pool_address),
            _toAsset,
            uint128(_amountIn),
            lowerTick,
            upperTick
        ))
        .mul(998)
        .div(1000);

        INonfungiblePositionManager(UNI_POS_MANAGER).approve(address(_zapper), _tokenId);

        WidoZapperUniswapV3.ZapOutOrder memory zap = WidoZapperUniswapV3.ZapOutOrder({
            pool: IUniswapV3Pool(pool.pool_address),
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

    function tickers(Ticker ticker, address pool) private view returns (int24 lowerTick, int24 upperTick) {
        (, int24 tick, , , , ,) = IUniswapV3Pool(pool).slot0();
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();
        int24 lower = int24(tick / tickSpacing) * tickSpacing;
        int24 upper = lower + tickSpacing;

        if (lower < upper) {
            lowerTick = lower;
            upperTick = upper;
        }
        else {
            lowerTick = upper;
            upperTick = lower;
        }

        if (ticker == Ticker.Low) {
            lowerTick -= tickSpacing;
            upperTick -= tickSpacing;
        }
        else if (ticker == Ticker.High) {
            lowerTick += tickSpacing;
            upperTick += tickSpacing;
        }
    }
}
