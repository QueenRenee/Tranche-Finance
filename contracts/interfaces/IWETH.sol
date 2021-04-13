// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IWETH {
  function deposit() external payable;
  function withdraw(uint256) external;
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address source, address receiver, uint256 amount) external returns (bool);
}
