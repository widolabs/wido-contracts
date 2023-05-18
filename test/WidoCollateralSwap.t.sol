// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../contracts/WidoCollateralSwap.sol";
import "./mocks/MockSwap.sol";
import "../contracts/interfaces/IComet.sol";
import "./interfaces/ICometTest.sol";
import "./ForkTest.sol";

contract WidoCollateralSwapTest is ForkTest {
    using SafeMath for uint256;
    WidoCollateralSwap widoCollateralSwap;
    MockSwap mockSwap;

    IERC3156FlashLender constant flashLoanProvider = IERC3156FlashLender(0x4EAF187ad4cE325bF6C84070b51c2f7224A51321);
    ICometTest constant cometUsdc = ICometTest(0xc3d688B66703497DAA19211EEdff47f25384cdc3);

    WidoCollateralSwap.Collateral existingCollateral = WidoCollateralSwap.Collateral(WBTC, 0.06e8);
    WidoCollateralSwap.Collateral finalCollateral = WidoCollateralSwap.Collateral(WETH, 1e18);

    event SupplyCollateral(address indexed from, address indexed dst, address indexed asset, uint amount);
    event WithdrawCollateral(address indexed src, address indexed to, address indexed asset, uint amount);

    function setUp() public {
        widoCollateralSwap = new WidoCollateralSwap(
            flashLoanProvider
        );
        mockSwap = new MockSwap(
            ERC20(WETH),
            ERC20(WBTC)
        );
    }

    function test_itWorks() public {
        /** Arrange */

        // deal necessary token amounts
        deal(existingCollateral.addr, user1, existingCollateral.amount);
        deal(finalCollateral.addr, address(mockSwap), finalCollateral.amount);

        // start impersonating user
        vm.startPrank(user1);

        // deposit into Compound
        IERC20(existingCollateral.addr).approve(address(cometUsdc), existingCollateral.amount);
        cometUsdc.supply(existingCollateral.addr, existingCollateral.amount);

        // take a loan
        cometUsdc.withdraw(address(USDC), 1000e6);

        // track the initial principal
        int104 initialPrincipal = userPrincipal(user1);

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit SupplyCollateral(address(widoCollateralSwap), user1, address(0), 0);

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit WithdrawCollateral(user1, address(widoCollateralSwap), address(0), 0);

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        WidoCollateralSwap.Signature memory allowSignature = sign(
            user1,
            address(widoCollateralSwap),
            true,
            nonce,
            10e9,
            cometUsdc.name(),
            cometUsdc.version()
        );

        // generate revoke signature
        nonce = nonce.add(1);
        WidoCollateralSwap.Signature memory revokeSignature = sign(
            user1,
            address(widoCollateralSwap),
            false,
            nonce,
            10e9,
            cometUsdc.name(),
            cometUsdc.version()
        );

        WidoCollateralSwap.Signatures memory sigs = WidoCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        bytes memory widoRouterCalldata = generateWidoRouterCalldata(existingCollateral, finalCollateral);

        WidoCollateralSwap.WidoSwap memory swap = WidoCollateralSwap.WidoSwap(
            address(widoRouter),
            address(widoTokenManager),
            widoRouterCalldata
        );

        /** Act */

        widoCollateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swap,
            address(cometUsdc)
        );

        /** Assert */

        // test allow is negative
        assertFalse(cometUsdc.isAllowed(user1, address(widoCollateralSwap)), "Manager still allowed");

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

    /// @dev Generates the signature values for the `allowBySig` function
    function sign(
        address owner,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry,
        string memory name,
        string memory version
    ) internal view returns (WidoCollateralSwap.Signature memory) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(cometUsdc)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Authorization(address owner,address manager,bool isAllowed,uint256 nonce,uint256 expiry)"),
                owner,
                manager,
                isAllowed,
                nonce,
                expiry
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        return WidoCollateralSwap.Signature(v, r, s);
    }

    function userPrincipal(address user) internal returns (int104) {
        ICometTest.UserBasic memory _userBasic = cometUsdc.userBasic(user);
        return _userBasic.principal;
    }

    function userCollateral(address user, address asset) internal returns (uint128) {
        ICometTest.UserCollateral memory _userCollateral = cometUsdc.userCollateral(user, asset);
        return _userCollateral.balance;
    }

    function generateWidoRouterCalldata(
        WidoCollateralSwap.Collateral memory _existingCollateral,
        WidoCollateralSwap.Collateral memory _finalCollateral
    ) internal view returns (bytes memory) {
        IWidoRouter.OrderInput[] memory inputs = new IWidoRouter.OrderInput[](1);
        inputs[0] = IWidoRouter.OrderInput(_existingCollateral.addr, _existingCollateral.amount);

        IWidoRouter.OrderOutput[] memory outputs = new IWidoRouter.OrderOutput[](1);
        outputs[0] = IWidoRouter.OrderOutput(_finalCollateral.addr, _finalCollateral.amount);

        IWidoRouter.Order memory order = IWidoRouter.Order(inputs, outputs, address(widoCollateralSwap), 0, 0);

        IWidoRouter.Step[] memory steps = new IWidoRouter.Step[](1);
        steps[0].targetAddress = address(mockSwap);
        steps[0].fromToken = _existingCollateral.addr;
        steps[0].data = abi.encodeWithSignature(
            "swapWbtcToWeth(uint256,uint256,address)",
            _existingCollateral.amount,
            _finalCollateral.amount,
            address(widoRouter)
        );
        steps[0].amountIndex = - 1;

        return abi.encodeWithSelector(
            0x916a3bd9, // "executeOrder(Order,Step[],uint256,address)",
            order,
            steps,
            0,
            address(0)
        );
    }
}
