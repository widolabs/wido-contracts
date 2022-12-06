pragma solidity 0.8.7;

import "solmate/src/tokens/ERC20.sol";

contract Token1 is ERC20 {
    constructor() ERC20("Token1", "Token1", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract Token2 is ERC20 {
    constructor() ERC20("Token2", "Token2", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}