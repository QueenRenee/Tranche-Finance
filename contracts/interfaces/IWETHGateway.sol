// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IWETHGateway {
  function depositETH() external payable;
  function withdrawETH(uint256 amount) external;
}
