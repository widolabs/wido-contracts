// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./mocks/MockSwap.sol";
import "./interfaces/ICometTest.sol";
import "../shared/MainnetForkTest.sol";
import "../../contracts/compound/interfaces/IComet.sol";
import "../../contracts/compound/interfaces/IWidoCollateralSwap.sol";
import "../../contracts/compound/libraries/LibCollateralSwap.sol";
import "../../contracts/compound/WidoCollateralSwap_Aave.sol";
import "../../contracts/compound/WidoCollateralSwap_ERC3156.sol";

contract WidoCollateralSwapTest is MainnetForkTest {
    using SafeMath for uint256;
    WidoCollateralSwap_Aave widoCollateralSwap_Aave;
    WidoCollateralSwap_ERC3156 widoCollateralSwap_Equalizer;
    MockSwap mockSwap;

    /// @dev This is the max number of providers on the enum Provider
    uint8 constant MAX_PROVIDERS = 2;
    enum Provider {
        Equalizer,
        Aave
    }

    IERC3156FlashLender constant equalizerLender = IERC3156FlashLender(0x4EAF187ad4cE325bF6C84070b51c2f7224A51321);
    IPoolAddressesProvider constant aaveAddressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    ICometTest constant cometUsdc = ICometTest(0xc3d688B66703497DAA19211EEdff47f25384cdc3);
    IComet constant cometMarketUsdc = IComet(0xc3d688B66703497DAA19211EEdff47f25384cdc3);

    LibCollateralSwap.Collateral existingCollateral = LibCollateralSwap.Collateral(WBTC, 0.06e8);
    LibCollateralSwap.Collateral finalCollateral = LibCollateralSwap.Collateral(WETH, 1e18);

    event SupplyCollateral(address indexed from, address indexed dst, address indexed asset, uint amount);
    event WithdrawCollateral(address indexed src, address indexed to, address indexed asset, uint amount);

    function setUp() public {
        setUpBase();

        // Create different contracts instances
        widoCollateralSwap_Aave = new WidoCollateralSwap_Aave(
            aaveAddressesProvider,
            cometMarketUsdc,
            address(widoRouter),
            address(widoTokenManager)
        );
        widoCollateralSwap_Equalizer = new WidoCollateralSwap_ERC3156(
            equalizerLender,
            cometMarketUsdc,
            address(widoRouter),
            address(widoTokenManager)
        );

        mockSwap = new MockSwap(
            ERC20(WETH),
            ERC20(WBTC)
        );

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

    function test_itWorks_WhenAmountIsTheExpected(uint8 _p) public {
        /** Arrange */

        Provider provider = _getProvider(_p);
        IWidoCollateralSwap _collateralSwap = _getContract(provider);

        uint256 fee = _providerFee(provider, finalCollateral.addr, finalCollateral.amount);

        // track the initial principal
        int104 initialPrincipal = _userPrincipal(user1);

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        LibCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(_collateralSwap),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        LibCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(_collateralSwap),
            false,
            nonce.add(1),
            10e9
        );

        LibCollateralSwap.Signatures memory sigs = LibCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        bytes memory swapCallData = _generateWidoRouterCalldata(existingCollateral, finalCollateral, finalCollateral.amount, address(_collateralSwap));

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit SupplyCollateral(address(_collateralSwap), user1, address(0), 0);

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit WithdrawCollateral(user1, address(_collateralSwap), address(0), 0);

        /** Act */

        _collateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swapCallData
        );

        /** Assert */

        // test allow is negative
        assertFalse(cometUsdc.isAllowed(user1, address(_collateralSwap)), "Manager still allowed");

        // user doesn't have initial collateral
        assertEq(_userCollateral(user1, existingCollateral.addr), 0, "Initial collateral not zero");

        // user has final collateral deposited
        assertEq(_userCollateral(user1, finalCollateral.addr), finalCollateral.amount - fee, "Final collateral not deposited");

        // loan is still collateralized
        assertTrue(cometUsdc.isBorrowCollateralized(user1), "Position not collateralized");

        // principal of user has not changed
        int104 finalPrincipal = _userPrincipal(user1);
        assertEq(initialPrincipal, finalPrincipal, "Principal has changed");
    }

    function test_itWorks_WhenPositiveSlippage(uint8 _p) public {
        /** Arrange */

        Provider provider = _getProvider(_p);
        IWidoCollateralSwap _collateralSwap = _getContract(provider);

        uint256 fee = _providerFee(provider, finalCollateral.addr, finalCollateral.amount);

        // track the initial principal
        int104 initialPrincipal = _userPrincipal(user1);

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        LibCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(_collateralSwap),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        LibCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(_collateralSwap),
            false,
            nonce.add(1),
            10e9
        );

        LibCollateralSwap.Signatures memory sigs = LibCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        // increase output amount to fake positive slippage
        uint256 _outputAmount = finalCollateral.amount.add(1000);

        bytes memory swapCallData = _generateWidoRouterCalldata(existingCollateral, finalCollateral, _outputAmount, address(_collateralSwap));

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit SupplyCollateral(address(_collateralSwap), user1, address(0), 0);

        // define expected Event
        vm.expectEmit(true, true, false, false);
        emit WithdrawCollateral(user1, address(_collateralSwap), address(0), 0);

        /** Act */

        _collateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swapCallData
        );

        /** Assert */

        // test allow is negative
        assertFalse(cometUsdc.isAllowed(user1, address(_collateralSwap)), "Manager still allowed");

        // user doesn't have initial collateral
        assertEq(_userCollateral(user1, existingCollateral.addr), 0, "Initial collateral not zero");

        // user has final collateral deposited
        assertEq(_userCollateral(user1, finalCollateral.addr), _outputAmount - fee, "Final collateral not deposited");

        // loan is still collateralized
        assertTrue(cometUsdc.isBorrowCollateralized(user1), "Position not collateralized");

        // principal of user has not changed
        int104 finalPrincipal = _userPrincipal(user1);
        assertEq(initialPrincipal, finalPrincipal, "Principal has changed");
    }

    function test_revertIf_NegativeSlippage(uint8 _p) public {
        /** Arrange */

        Provider provider = _getProvider(_p);
        IWidoCollateralSwap _collateralSwap = _getContract(provider);

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        LibCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(_collateralSwap),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        LibCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(_collateralSwap),
            false,
            nonce.add(1),
            10e9
        );

        LibCollateralSwap.Signatures memory sigs = LibCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        // increase output amount to fake negative slippage
        uint256 _outputAmount = finalCollateral.amount.sub(1000);

        bytes memory swapCallData = _generateWidoRouterCalldata(existingCollateral, finalCollateral, _outputAmount, address(_collateralSwap));

        /** Assert */

        vm.expectRevert();

        /** Act */

        _collateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swapCallData
        );
    }

    function test_revertWhen_AllowSignatureHasWrongManager(uint8 _p) public {
        /** Arrange */

        Provider provider = _getProvider(_p);
        IWidoCollateralSwap _collateralSwap = _getContract(provider);

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        LibCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(0),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        LibCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(_collateralSwap),
            false,
            nonce.add(1),
            10e9
        );

        LibCollateralSwap.Signatures memory sigs = LibCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        bytes memory swapCallData = _generateWidoRouterCalldata(existingCollateral, finalCollateral, finalCollateral.amount, address(_collateralSwap));

        /** Assert */

        vm.expectRevert(bytes4(0x40622f2c));

        /** Act */

        _collateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swapCallData
        );
    }

    function test_revertWhen_AllowSignatureHasWrongExpiry(uint8 _p) public {
        /** Arrange */

        Provider provider = _getProvider(_p);
        IWidoCollateralSwap _collateralSwap = _getContract(provider);

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        LibCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(_collateralSwap),
            true,
            nonce,
            9e9
        );

        // generate revoke signature
        LibCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(_collateralSwap),
            false,
            nonce.add(1),
            10e9
        );

        LibCollateralSwap.Signatures memory sigs = LibCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        bytes memory swapCallData =  _generateWidoRouterCalldata(existingCollateral, finalCollateral, finalCollateral.amount, address(_collateralSwap));

        /** Assert */

        vm.expectRevert(bytes4(0x40622f2c));

        /** Act */

        _collateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swapCallData
        );
    }

    function test_revertWhen_SignaturesAreNotConsecutive(uint8 _p) public {
        /** Arrange */

        Provider provider = _getProvider(_p);
        IWidoCollateralSwap _collateralSwap = _getContract(provider);

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        LibCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(_collateralSwap),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        LibCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(_collateralSwap),
            false,
            nonce, // <-- NOT BEING INCREMENTED
            10e9
        );

        LibCollateralSwap.Signatures memory sigs = LibCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        bytes memory swapCallData =  _generateWidoRouterCalldata(existingCollateral, finalCollateral, finalCollateral.amount, address(_collateralSwap));

        /** Assert */

        vm.expectRevert(bytes4(0x40622f2c));

        /** Act */

        _collateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swapCallData
        );
    }

    function test_revertWhen_RevokeSignatureHasWrongManager(uint8 _p) public {
        /** Arrange */

        Provider provider = _getProvider(_p);
        IWidoCollateralSwap _collateralSwap = _getContract(provider);

        // generate allow signature
        uint256 nonce = cometUsdc.userNonce(user1);
        LibCollateralSwap.Signature memory allowSignature = _sign(
            user1,
            address(_collateralSwap),
            true,
            nonce,
            10e9
        );

        // generate revoke signature
        LibCollateralSwap.Signature memory revokeSignature = _sign(
            user1,
            address(0),
            false,
            nonce.add(1),
            10e9
        );

        LibCollateralSwap.Signatures memory sigs = LibCollateralSwap.Signatures(
            allowSignature,
            revokeSignature
        );

        bytes memory swapCallData =  _generateWidoRouterCalldata(existingCollateral, finalCollateral, finalCollateral.amount, address(_collateralSwap));

        /** Assert */

        vm.expectRevert(bytes4(0x40622f2c));

        /** Act */

        _collateralSwap.swapCollateral(
            existingCollateral,
            finalCollateral,
            sigs,
            swapCallData
        );
    }

    /// Helpers

    /// @dev Returns the right contract depending the provider
    function _getContract(
        Provider _provider
    ) internal view returns (IWidoCollateralSwap) {
        if (_provider == Provider.Equalizer) {
            return widoCollateralSwap_Equalizer;
        }
        else if (_provider == Provider.Aave) {
            return widoCollateralSwap_Aave;
        }
        else {
            revert("Wrong provider");
        }
    }

    /// @dev Converts a fuzzed uint8 into a Provider type
    function _getProvider(uint8 _p) internal pure returns (Provider) {
        vm.assume(_p < MAX_PROVIDERS);
        return Provider(_p);
    }

    /// @dev Fetch the required fee for the given provider/token/amount
    function _providerFee(
        Provider _provider,
        address _token,
        uint256 _amount
    ) internal view returns (uint256) {
        if (_provider == Provider.Equalizer) {
            return equalizerLender.flashFee(_token, _amount);
        }
        else if (_provider == Provider.Aave) {
            uint128 feeBps = IPool(aaveAddressesProvider.getPool()).FLASHLOAN_PREMIUM_TOTAL();
            return uint256(_amount * feeBps / 10000);
        }
        else {
            revert("Provider not implemented");
        }
    }

    /// @dev Generates the signature values for the `allowBySig` function
    function _sign(
        address owner,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry
    ) internal returns (LibCollateralSwap.Signature memory) {
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
        return LibCollateralSwap.Signature(v, r, s);
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
        LibCollateralSwap.Collateral memory _existingCollateral,
        LibCollateralSwap.Collateral memory _finalCollateral,
        uint256 _amountOut,
        address _contractAddress
    ) internal view returns (bytes memory) {
        IWidoRouter.OrderInput[] memory inputs = new IWidoRouter.OrderInput[](1);
        inputs[0] = IWidoRouter.OrderInput(_existingCollateral.addr, _existingCollateral.amount);

        IWidoRouter.OrderOutput[] memory outputs = new IWidoRouter.OrderOutput[](1);
        outputs[0] = IWidoRouter.OrderOutput(_finalCollateral.addr, _finalCollateral.amount);

        IWidoRouter.Order memory order = IWidoRouter.Order(inputs, outputs, _contractAddress, 0, 0);

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
}
