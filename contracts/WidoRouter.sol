//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IStargateRouter.sol";
import "../interfaces/IWidoRouter.sol";

contract WidoRouter is IWidoRouter, Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            abi.encodePacked(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
            )
        );

    bytes32 private constant ORDER_TYPEHASH =
        keccak256(
            abi.encodePacked(
                "Order(address user,address fromToken,address toToken,uint256 fromTokenAmount,uint256 minToTokenAmount,uint32 nonce,uint32 expiration)"
            )
        );

    bytes32 public DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    mapping(address => bool) public approvedSwapAddresses;

    bytes32 private constant CROSS_CHAIN_ORDER_TYPEHASH =
        keccak256(
            abi.encodePacked(
                "CrossChainOrder(address user,address fromToken,uint32 fromChainId,address toToken,uint32 toChainId,uint256 fromTokenAmount,uint256 minToTokenAmount,uint32 nonce,uint32 expiration)"
            )
        );

    uint256 chainId;

    IStargateRouter public stargateRouter;
    mapping(uint32 => uint16) stargateChainId;
    mapping(uint16 => uint16) approvePoolIdPair;

    function initialize(uint256 _chainId, address _stargateRouter)
        public
        initializer
    {
        __Ownable_init();

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256("WidoRouter"),
                keccak256("1"),
                _chainId,
                address(this)
            )
        );

        chainId = _chainId;
        stargateRouter = IStargateRouter(_stargateRouter);
    }

    function addApprovedSwapAddress(address _swapAddress) public onlyOwner {
        approvedSwapAddresses[_swapAddress] = true;
    }

    function removeApprovedSwapAddress(address _swapAddress) public onlyOwner {
        delete approvedSwapAddresses[_swapAddress];
    }

    function setStargateRouter(address _stargateRouter) public onlyOwner {
        stargateRouter = IStargateRouter(_stargateRouter);
    }

    function setStargateChainId(uint32 _chainId, uint16 _stargateChainId)
        public
        onlyOwner
    {
        stargateChainId[_chainId] = _stargateChainId;
    }

    function _getDigest(Order memory order) private view returns (bytes32) {
        bytes32 data = keccak256(abi.encode(ORDER_TYPEHASH, order));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, data));
    }

    function _getCrossChainOrderDigest(CrossChainOrder memory order)
        private
        view
        returns (bytes32)
    {
        bytes32 data = keccak256(abi.encode(CROSS_CHAIN_ORDER_TYPEHASH, order));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, data));
    }

    function _pullTokens(
        address user,
        address token,
        uint256 amount
    ) internal returns (uint256) {
        IERC20Upgradeable(token).safeTransferFrom(user, address(this), amount);
        return amount;
    }

    function _approveToken(
        address token,
        address spender,
        uint256 amount
    ) internal {
        IERC20Upgradeable _token = IERC20Upgradeable(token);
        if (_token.allowance(address(this), spender) >= amount) return;
        else {
            _token.safeApprove(spender, type(uint256).max);
        }
    }

    function _executeSwaps(SwapRoute[] memory swapRoute) private {
        for (uint256 i = 0; i < swapRoute.length; i++) {
            SwapRoute memory path = swapRoute[i];
            require(
                approvedSwapAddresses[path.swapAddress],
                "Swap address not authorized"
            );

            uint256 balance = IERC20Upgradeable(path.fromToken).balanceOf(
                address(this)
            );
            _approveToken(path.fromToken, path.swapAddress, balance);

            (bool success, ) = path.swapAddress.call(path.swapData);
            require(success, "Routing failed");
        }
    }

    function verifyOrderRequest(
        Order memory order,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view override returns (bool) {
        address recoveredAddress = ecrecover(_getDigest(order), v, r, s);
        require(
            recoveredAddress != address(0) && order.user == recoveredAddress,
            "Invalid signature"
        );
        require(order.nonce == nonces[order.user], "Invalid nonce");
        require(
            order.expiration == 0 || block.timestamp <= order.expiration,
            "Expired request"
        );
        require(order.fromTokenAmount > 0, "Amount should be greater than 0");
        return true;
    }

    function verifyCrossChainOrderRequest(
        CrossChainOrder memory order,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view returns (bool) {
        address recoveredAddress = ecrecover(
            _getCrossChainOrderDigest(order),
            v,
            r,
            s
        );
        require(
            recoveredAddress != address(0) && order.user == recoveredAddress,
            "Invalid signature"
        );
        require(order.nonce == nonces[order.user], "Invalid nonce");
        require(
            order.expiration == 0 || block.timestamp <= order.expiration,
            "Expired request"
        );
        require(order.fromTokenAmount > 0, "Amount should be greater than 0");
        return true;
    }

    function _executeOrder(Order memory order, SwapRoute[] calldata swapRoute)
        private
        returns (uint256 toTokenBalance)
    {
        // Check Input Token
        _pullTokens(order.user, order.fromToken, order.fromTokenAmount);
        uint256 fromTokenBalance = IERC20Upgradeable(order.fromToken).balanceOf(
            address(this)
        );
        require(fromTokenBalance >= order.fromTokenAmount);

        _executeSwaps(swapRoute);

        // Check Output Token
        toTokenBalance = IERC20Upgradeable(order.toToken).balanceOf(
            address(this)
        );
        require(toTokenBalance >= order.minToTokenAmount);

        // Distribute Token
        IERC20Upgradeable(order.toToken).transfer(order.user, toTokenBalance);
    }

    function _executeCrossChainOrder(
        CrossChainOrder memory order,
        SwapRoute[] calldata srcSwapRoute,
        SwapRoute[] calldata dstSwapRoute,
        BridgeOptions calldata bridgeOptions
    ) private {
        require(chainId == order.fromChainId);
        // Check Input Token
        _pullTokens(order.user, order.fromToken, order.fromTokenAmount);
        uint256 fromTokenBalance = IERC20Upgradeable(order.fromToken).balanceOf(
            address(this)
        );
        require(fromTokenBalance >= order.fromTokenAmount);

        _executeSwaps(srcSwapRoute);

        uint256 bridgeTokenBalance = IERC20Upgradeable(
            bridgeOptions.bridgeToken
        ).balanceOf(address(this));

        _approveToken(
            bridgeOptions.bridgeToken,
            address(stargateRouter),
            bridgeTokenBalance
        );

        {
            bytes memory payload = "";
            if (bridgeOptions.dstGasForCall > 0) {
                payload = abi.encode(order, dstSwapRoute);
            } else {
                require(bridgeOptions.dstAddress == order.user);
            }
            stargateRouter.swap{value: msg.value}(
                stargateChainId[order.toChainId], // stargateDstChainId,
                bridgeOptions.srcPoolId, // stargateSrcPoolId,
                bridgeOptions.dstPoolId, // stargateDstPoolId,
                payable(_msgSender()), // Refund Address.
                bridgeTokenBalance,
                bridgeOptions.minBridgedToken,
                IStargateRouter.lzTxObj(bridgeOptions.dstGasForCall, 0, "0x"),
                abi.encodePacked(bridgeOptions.dstAddress),
                payload
            );
        }
    }

    function executeOrder(Order memory order, SwapRoute[] calldata swapRoute)
        external
        override
        returns (uint256 toTokenBalance)
    {
        require(_msgSender() == order.user);
        toTokenBalance = _executeOrder(order, swapRoute);
    }

    function executeOrderWithSignature(
        Order memory order,
        SwapRoute[] calldata swapRoute,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (uint256 toTokenBalance) {
        // Verify Order
        require(verifyOrderRequest(order, v, r, s) == true);
        toTokenBalance = _executeOrder(order, swapRoute);
        // Update nonce
        nonces[order.user]++;
    }

    function executeCrossChainOrder(
        CrossChainOrder memory order,
        SwapRoute[] calldata srcSwapRoute,
        SwapRoute[] calldata dstSwapRoute,
        BridgeOptions calldata bridgeOptions
    ) external payable override {
        require(_msgSender() == order.user);
        _executeCrossChainOrder(
            order,
            srcSwapRoute,
            dstSwapRoute,
            bridgeOptions
        );
    }

    function executeCrossChainOrderWithSignature(
        CrossChainOrder memory order,
        uint8 v,
        bytes32 r,
        bytes32 s,
        SwapRoute[] calldata srcSwapRoute,
        SwapRoute[] calldata dstSwapRoute,
        BridgeOptions calldata bridgeOptions
    ) external payable override {
        // Verify Order
        require(verifyCrossChainOrderRequest(order, v, r, s) == true);
        _executeCrossChainOrder(
            order,
            srcSwapRoute,
            dstSwapRoute,
            bridgeOptions
        );
        // Update nonce
        nonces[order.user]++;
    }
}
