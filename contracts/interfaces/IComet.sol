// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

interface IComet {
    function withdrawFrom(address src, address to, address asset, uint amount) external;

    function supplyTo(address dst, address asset, uint amount) external;
}
