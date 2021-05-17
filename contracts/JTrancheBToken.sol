// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./interfaces/IJTrancheTokens.sol";
import "./JTrancheBTokenStorage.sol";


contract JTrancheBToken is OwnableUpgradeable, ERC20Upgradeable, AccessControlUpgradeable, JTrancheBTokenStorage, IJTrancheTokens {
	using SafeMathUpgradeable for uint256;

	function initialize(string memory name, string memory symbol) external initializer() {
		OwnableUpgradeable.__Ownable_init();
        __ERC20_init(name, symbol);
		// Grant the minter role to a specified account
        _setupRole(MINTER_ROLE, msg.sender);
	}

    function setJAaveMinter(address _jAave) external onlyOwner {
		// Grant the minter role to a specified account
        _setupRole(MINTER_ROLE, _jAave);
	}

    /**
	 * @dev Internal function that mints tokens to an account.
	 * Update pointsCorrection to keep funds unchanged.
	 * @param account The account that will receive the created tokens.
	 * @param value The amount that will be created.
	 */
	function mint(address account, uint256 value) external override {
		require(hasRole(MINTER_ROLE, msg.sender), "JTrancheB: Caller is not a minter");
		require(value > 0, "JTrancheB: value is zero");
        super._mint(account, value);
    }

    /** 
	 * @dev Internal function that burns an amount of the token of a given account.
	 * Update pointsCorrection to keep funds unchanged.
	 * @param value The amount that will be burnt.
	 */
	function burn(uint256 value) external override {
		require(value > 0, "JTrancheB: value is zero");
		super._burn(msg.sender, value);
	}
}