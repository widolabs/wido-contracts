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

    function test_itWorks_WhenAmountIsTheExpected() public {
        /** Arrange */

        _setupLoanScenario();

        // track the initial principal
        int104 initialPrincipal = _userPrincipal(user1);

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit SupplyCollateral(address(widoCollateralSwap), user1, address(0), 0);

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit WithdrawCollateral(user1, address(widoCollateralSwap), address(0), 0);

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        WidoCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(widoCollateralSwap),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        WidoCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(widoCollateralSwap),
            false,
            nonce.add(1),
            10e9
        );

        WidoCollateralSwap.Signatures memory sigs = WidoCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        WidoCollateralSwap.WidoSwap memory swap = WidoCollateralSwap.WidoSwap(
            address(widoRouter),
            address(widoTokenManager),
            _generateWidoRouterCalldata(existingCollateral, finalCollateral, finalCollateral.amount)
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
        assertEq(_userCollateral(user1, existingCollateral.addr), 0, "Initial collateral not zero");

        // user has final collateral deposited
        assertEq(_userCollateral(user1, finalCollateral.addr), finalCollateral.amount, "Final collateral not deposited");

        // loan is still collateralized
        assertTrue(cometUsdc.isBorrowCollateralized(user1), "Position not collateralized");

        // principal of user has not changed
        int104 finalPrincipal = _userPrincipal(user1);
        assertEq(initialPrincipal, finalPrincipal, "Principal has changed");
    }

    function test_itWorks_WhenPositiveSlippage() public {
        /** Arrange */

        _setupLoanScenario();

        // track the initial principal
        int104 initialPrincipal = _userPrincipal(user1);

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit SupplyCollateral(address(widoCollateralSwap), user1, address(0), 0);

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit WithdrawCollateral(user1, address(widoCollateralSwap), address(0), 0);

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        WidoCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(widoCollateralSwap),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        WidoCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(widoCollateralSwap),
            false,
            nonce.add(1),
            10e9
        );

        WidoCollateralSwap.Signatures memory sigs = WidoCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        // increase output amount to fake positive slippage
        uint256 _outputAmount = finalCollateral.amount.add(1000);

        WidoCollateralSwap.WidoSwap memory swap = WidoCollateralSwap.WidoSwap(
            address(widoRouter),
            address(widoTokenManager),
            _generateWidoRouterCalldata(existingCollateral, finalCollateral, _outputAmount)
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
        assertEq(_userCollateral(user1, existingCollateral.addr), 0, "Initial collateral not zero");

        // user has final collateral deposited
        assertEq(_userCollateral(user1, finalCollateral.addr), _outputAmount, "Final collateral not deposited");

        // loan is still collateralized
        assertTrue(cometUsdc.isBorrowCollateralized(user1), "Position not collateralized");

        // principal of user has not changed
        int104 finalPrincipal = _userPrincipal(user1);
        assertEq(initialPrincipal, finalPrincipal, "Principal has changed");
    }

    function test_revertIf_NegativeSlippage() public {
        /** Arrange */

        _setupLoanScenario();

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        WidoCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(widoCollateralSwap),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        WidoCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(widoCollateralSwap),
            false,
            nonce.add(1),
            10e9
        );

        WidoCollateralSwap.Signatures memory sigs = WidoCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        // increase output amount to fake negative slippage
        uint256 _outputAmount = finalCollateral.amount.sub(1000);

        WidoCollateralSwap.WidoSwap memory swap = WidoCollateralSwap.WidoSwap(
            address(widoRouter),
            address(widoTokenManager),
            _generateWidoRouterCalldata(existingCollateral, finalCollateral, _outputAmount)
        );

        /** Assert */

        vm.expectRevert();

        /** Act */

        widoCollateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swap,
            address(cometUsdc)
        );
    }

    function test_revertWhen_AllowSignatureHasWrongManager() public {
        /** Arrange */

        _setupLoanScenario();

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        WidoCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(0),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        WidoCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(widoCollateralSwap),
            false,
            nonce.add(1),
            10e9
        );

        WidoCollateralSwap.Signatures memory sigs = WidoCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        WidoCollateralSwap.WidoSwap memory swap = WidoCollateralSwap.WidoSwap(
            address(widoRouter),
            address(widoTokenManager),
            _generateWidoRouterCalldata(existingCollateral, finalCollateral, finalCollateral.amount)
        );

        /** Assert */

        vm.expectRevert(bytes4(0x40622f2c));

        /** Act */

        widoCollateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swap,
            address(cometUsdc)
        );
    }

    function test_revertWhen_AllowSignatureHasWrongExpiry() public {
        /** Arrange */

        _setupLoanScenario();

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        WidoCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(widoCollateralSwap),
            true,
            nonce,
            9e9
        );

        // generate revoke signature
        WidoCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(widoCollateralSwap),
            false,
            nonce.add(1),
            10e9
        );

        WidoCollateralSwap.Signatures memory sigs = WidoCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        WidoCollateralSwap.WidoSwap memory swap = WidoCollateralSwap.WidoSwap(
            address(widoRouter),
            address(widoTokenManager),
            _generateWidoRouterCalldata(existingCollateral, finalCollateral, finalCollateral.amount)
        );

        /** Assert */

        vm.expectRevert(bytes4(0x40622f2c));

        /** Act */

        widoCollateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swap,
            address(cometUsdc)
        );
    }

    function test_revertWhen_SignaturesAreNotConsecutive() public {
        /** Arrange */

        _setupLoanScenario();

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        WidoCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(widoCollateralSwap),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        WidoCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(widoCollateralSwap),
            false,
            nonce, // <-- NOT BEING INCREMENTED
            10e9
        );

        WidoCollateralSwap.Signatures memory sigs = WidoCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        WidoCollateralSwap.WidoSwap memory swap = WidoCollateralSwap.WidoSwap(
            address(widoRouter),
            address(widoTokenManager),
            _generateWidoRouterCalldata(existingCollateral, finalCollateral, finalCollateral.amount)
        );

        /** Assert */

        vm.expectRevert(bytes4(0x40622f2c));

        /** Act */

        widoCollateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swap,
            address(cometUsdc)
        );
    }

    function test_revertWhen_RevokeSignatureHasWrongManager() public {
        /** Arrange */

        _setupLoanScenario();

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        WidoCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(widoCollateralSwap),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        WidoCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(0),
            false,
            nonce.add(1),
            10e9
        );

        WidoCollateralSwap.Signatures memory sigs = WidoCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        WidoCollateralSwap.WidoSwap memory swap = WidoCollateralSwap.WidoSwap(
            address(widoRouter),
            address(widoTokenManager),
            _generateWidoRouterCalldata(existingCollateral, finalCollateral, finalCollateral.amount)
        );

        /** Assert */

        vm.expectRevert(bytes4(0x40622f2c));

        /** Act */

        widoCollateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swap,
            address(cometUsdc)
        );
    }

    /// Helpers

    /// @dev Generates the signature values for the `allowBySig` function
    function _sign(
        address owner,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry
    ) internal returns (WidoCollateralSwap.Signature memory) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(cometUsdc.name())),
                keccak256(bytes(cometUsdc.version())),
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

    /// @dev Return the principal amount of the user
    function _userPrincipal(address user) internal returns (int104) {
        ICometTest.UserBasic memory userBasic = cometUsdc.userBasic(user);
        return userBasic.principal;
    }

    /// @dev Return the collateral amount of the user
    function _userCollateral(address user, address asset) internal returns (uint128) {
        ICometTest.UserCollateral memory userCollateral = cometUsdc.userCollateral(user, asset);
        return userCollateral.balance;
    }

    /// @dev Generate a calldata for the WidoRouter
    function _generateWidoRouterCalldata(
        WidoCollateralSwap.Collateral memory _existingCollateral,
        WidoCollateralSwap.Collateral memory _finalCollateral,
        uint256 _amountOut
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
            _amountOut,
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

    /// @dev Sets everything up so the user has a valid Compound position and a loan
    function _setupLoanScenario() internal {
        // deal necessary token amounts
        deal(existingCollateral.addr, user1, existingCollateral.amount);
        deal(finalCollateral.addr, address(mockSwap), finalCollateral.amount.mul(2));

        // start impersonating user
        vm.startPrank(user1);

        // deposit into Compound
        IERC20(existingCollateral.addr).approve(address(cometUsdc), existingCollateral.amount);
        cometUsdc.supply(existingCollateral.addr, existingCollateral.amount);

        // take a loan
        cometUsdc.withdraw(address(USDC), 1000e6);
    }
}
