// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
  constructor() ERC20("Test Token", "TEST") {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}
