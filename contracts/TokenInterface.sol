// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

abstract contract TokenInterface {
    function deposit() public virtual payable;
    function withdraw(uint256) public virtual;
}
