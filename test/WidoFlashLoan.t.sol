// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "../contracts/WidoFlashLoan.sol";
import "./mocks/MockSwap.sol";
import "../contracts/interfaces/IComet.sol";
import "./interfaces/ICometTest.sol";

contract WidoFlashLoanTest is Test {
    WidoFlashLoan public widoFlashLoan;

    IERC3156FlashLender flashLoanProvider = IERC3156FlashLender(0x4EAF187ad4cE325bF6C84070b51c2f7224A51321);
    IWidoTokenManager widoTokenManager = IWidoTokenManager(0xF2F02200aEd0028fbB9F183420D3fE6dFd2d3EcD);
    IWidoRouter widoRouter = IWidoRouter(0x7Fb69e8fb1525ceEc03783FFd8a317bafbDfD394);
    ICometTest cometUsdc = ICometTest(0xc3d688B66703497DAA19211EEdff47f25384cdc3);

    MockSwap mockSwap;

    address WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address WBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address user1 = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    WidoFlashLoan.Collateral existingCollateral = WidoFlashLoan.Collateral(WBTC, 0.06e8);
    WidoFlashLoan.Collateral finalCollateral = WidoFlashLoan.Collateral(WETH, 1e18);

    event SupplyCollateral(address indexed from, address indexed dst, address indexed asset, uint amount);
    event WithdrawCollateral(address indexed src, address indexed to, address indexed asset, uint amount);

    function setUp() public {
        widoFlashLoan = new WidoFlashLoan(flashLoanProvider, widoRouter, widoTokenManager, IComet(address(cometUsdc)));
        mockSwap = new MockSwap(ERC20(WETH), ERC20(WBTC));
    }

    function test_itWorks() public {
        /** Arrange */

        // deal necessary amounts
        deal(existingCollateral.addr, user1, existingCollateral.amount);
        deal(finalCollateral.addr, address(mockSwap), finalCollateral.amount);

        // start impersonating user
        vm.startPrank(user1);

        // deposit into Compound
        IERC20(existingCollateral.addr).approve(address(cometUsdc), existingCollateral.amount);
        cometUsdc.supply(existingCollateral.addr, existingCollateral.amount);

        cometUsdc.withdraw(address(USDC), 1000e6);

        // track the initial principal
        int104 initialPrincipal = userPrincipal(user1);

        // give permission to WidoFlashLoan
        cometUsdc.allow(address(widoFlashLoan), true);

        // generate route for WidoRoute
        IWidoRouter.Step[] memory route = new IWidoRouter.Step[](1);
        route[0].targetAddress = address(mockSwap);
        route[0].fromToken = existingCollateral.addr;
        route[0].data = abi.encodeWithSignature(
            "swapWbtcToWeth(uint256,uint256,address)",
            existingCollateral.amount,
            finalCollateral.amount,
            address(widoRouter)
        );
        route[0].amountIndex = - 1;

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit SupplyCollateral(address(widoFlashLoan), user1, address(0), 0);

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit WithdrawCollateral(user1, address(widoFlashLoan), address(0), 0);

        /** Act */

        widoFlashLoan.swapCollateral(
            existingCollateral,
            finalCollateral,
            route,
            0,
            address(0)
        );

        /** Assert */

        // user doesn't have initial collateral
        assertEq(userCollateral(user1, existingCollateral.addr), 0);

        // user has final collateral deposited
        assertEq(userCollateral(user1, finalCollateral.addr), finalCollateral.amount);

        // loan is still collateralized
        assertTrue(cometUsdc.isBorrowCollateralized(user1));

        // principal of user has not changed
        int104 finalPrincipal = userPrincipal(user1);
        assertEq(initialPrincipal, finalPrincipal);
    }

    function userPrincipal(address user) internal returns (int104) {
        ICometTest.UserBasic memory _userBasic = cometUsdc.userBasic(user);
        return _userBasic.principal;
    }

    function userCollateral(address user, address asset) internal returns (uint128) {
        ICometTest.UserCollateral memory _userCollateral = cometUsdc.userCollateral(user, asset);
        return _userCollateral.balance;
    }
}
