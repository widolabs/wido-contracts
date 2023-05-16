// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

interface ICometTest {

    struct UserBasic {
        int104 principal;
        uint64 baseTrackingIndex;
        uint64 baseTrackingAccrued;
        uint16 assetsIn;
        uint8 _reserved;
    }

    struct UserCollateral {
        uint128 balance;
        uint128 _reserved;
    }

    function name() external returns (string memory);

    function version() external returns (string memory);

    function userNonce(address user) external returns (uint256);

    function supply(address asset, uint amount) external;

    function withdraw(address asset, uint amount) external;

    function userBasic(address user) external returns (UserBasic memory);

    function userCollateral(address user, address asset) external returns (UserCollateral memory);

    function allow(address manager, bool isAllowed_) external;

    function isBorrowCollateralized(address user) external returns (bool);

}
