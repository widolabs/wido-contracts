// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.7;

interface IWidoRouter {
    struct Order {
        address user;
        address fromToken;
        address toToken;
        uint256 fromTokenAmount;
        uint256 minToTokenAmount;
        uint32 nonce;
        uint32 expiration;
    }

    struct SwapRoute {
        address fromToken;
        address toToken;
        address swapAddress;
        bytes swapData;
    }

    struct CrossChainOrder {
        address user;
        address fromToken;
        uint32 fromChainId;
        address toToken;
        uint32 toChainId;
        uint256 fromTokenAmount;
        uint256 minToTokenAmount;
        uint32 nonce;
        uint32 expiration;
    }

    struct BridgeOptions {
        uint256 srcPoolId;
        uint256 dstPoolId;
        address bridgeToken;
        uint256 minBridgedToken;
        uint256 dstGasForCall;
        address dstAddress;
    }

    function verifyOrderRequest(
        Order memory order,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bool);

    function executeOrder(Order memory order, SwapRoute[] calldata swapRoute)
        external
        returns (uint256 toTokenBalance);

    function executeOrderWithSignature(
        Order memory order,
        SwapRoute[] calldata swapRoute,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 toTokenBalance);

    function executeCrossChainOrder(
        CrossChainOrder memory order,
        SwapRoute[] calldata srcSwapRoute,
        SwapRoute[] calldata dstSwapRoute,
        BridgeOptions calldata bridgeOptions
    ) external payable;

    function executeCrossChainOrderWithSignature(
        CrossChainOrder memory order,
        uint8 v,
        bytes32 r,
        bytes32 s,
        SwapRoute[] calldata srcSwapRoute,
        SwapRoute[] calldata dstSwapRoute,
        BridgeOptions calldata bridgeOptions
    ) external payable;
}
