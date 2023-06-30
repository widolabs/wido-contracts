// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../contracts/core/zapper/WidoZapperCamelot.sol";
import "../../shared/ArbitrumForkTest.sol";
import "../../../contracts/core/handlers/CamelotNftHandler.sol";

contract CamelotNftHandlerTest is ArbitrumForkTest {
    using SafeMath for uint256;

    CamelotNftHandler handler;

    address constant WETH_ARB_LP = address(0xa6c5C7D189fA4eB5Af8ba34E63dCDD3a635D433f);
    address constant WETH_ARB_NFT_POOL = address(0x9FFC53cE956Bf040c4465B73B3cfC04569EDaEf1);

    function setUp() public {
        setUpBase();

        handler = new CamelotNftHandler();
        vm.label(address(handler), "Handler");

        vm.label(WETH_ARB_LP, "WETH_ARB_LP");
        vm.label(WETH_ARB_NFT_POOL, "WETH_ARB_NFT_POOL");
    }

    function test_zapLPForNFT() public {
        /** Arrange */

        uint256 amount = 150_000_000;
        IERC20 fromAsset = IERC20(WETH_ARB_LP);
        NFTPool nftPool = NFTPool(WETH_ARB_NFT_POOL);
        deal(address(fromAsset), user1, amount);

        /** Act */

        vm.startPrank(user1);
        fromAsset.approve(address(handler), amount);
        handler.deposit(nftPool, fromAsset, amount, user1);
        vm.stopPrank();

        /** Assert */

        uint256 finalFromBalance = fromAsset.balanceOf(user1);
        uint256 userTokenId = nftPool.tokenOfOwnerByIndex(user1, 0);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertNotEq(userTokenId, 0, "Invalid token Id");
    }

}
