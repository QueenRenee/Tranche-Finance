// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IJAave {
    event TrancheAddedToProtocol(uint256 trancheNum, address trancheA, address trancheB);
    event TrancheATokenMinted(uint256 trancheNum, address buyer, uint256 amount, uint256 taAmount);
    event TrancheBTokenMinted(uint256 trancheNum, address buyer, uint256 amount, uint256 tbAmount);
    event TrancheATokenBurned(uint256 trancheNum, address burner, uint256 amount, uint256 taAmount);
    event TrancheBTokenBurned(uint256 trancheNum, address burner, uint256 amount, uint256 tbAmount);
}