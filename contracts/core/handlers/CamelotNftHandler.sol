// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface NFTPool {
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    function lastTokenId() external view returns (uint256);

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external;

    function createPosition(uint256 amount, uint256 lockDuration) external;

    function withdrawFromPosition(uint256 tokenId, uint256 amountToWithdraw) external;
}

contract CamelotNftHandler is IERC721Receiver {
    using SafeERC20 for IERC20;

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function deposit(NFTPool nftPool, IERC20 lpToken, uint256 amount, address recipient) external {
        lpToken.safeTransferFrom(msg.sender, address(this), amount);
        lpToken.safeApprove(address(nftPool), amount);
        nftPool.createPosition(amount, 0);
        uint256 tokenId = nftPool.lastTokenId();
        nftPool.safeTransferFrom(address(this), recipient, tokenId, bytes(""));
    }

    //function withdraw(address nftPool, IERC20 lpToken, uint256 amount, address recipient) external {
    //    uint256 balance = IERC20(lpToken).balanceOf(address(this));
    //    uint256 tokenId = NFTPool(nftPool).tokenOfOwnerByIndex(address(this), 0);
    //    NFTPool(nftPool).withdrawFromPosition(tokenId, amount);
    //    balance = IERC20(lpToken).balanceOf(address(this)) - balance;
    //    IERC20(lpToken).transfer(recipient, balance);
    //}
}
