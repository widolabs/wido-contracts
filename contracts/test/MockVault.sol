pragma solidity 0.8.7;

import "solmate/src/utils/SafeTransferLib.sol";

contract MockVault is ERC20 {
    using SafeTransferLib for ERC20;

    ERC20 public immutable underlying;

    constructor(address _underlying) ERC20("Vault", "VLT", 18) {
        underlying = ERC20(_underlying);
    }

    function deposit(uint256 amount) external {
        underlying.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        underlying.transfer(msg.sender, amount);
    }
}