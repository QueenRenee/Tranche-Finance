// SPDX-License-Identifier: MIT
/**
 * Created on 2021-02-11
 * @summary: Jibrel Aave Tranche Deployer
 * @author: Jibrel Team
 */
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./JTrancheAToken.sol";
import "./JTrancheBToken.sol";
import "./interfaces/IJTranchesDeployer.sol";
import "./JTranchesDeployerStorage.sol";

contract JTranchesDeployer is OwnableUpgradeable, IJTranchesDeployer {
    using SafeMathUpgradeable for uint256;

    address public jAaveAddress;

    function initialize() external initializer() {
        OwnableUpgradeable.__Ownable_init();
    }

    function setJAaveAddress(address _jAave) external onlyOwner {
        jAaveAddress = _jAave;
    }

    modifier onlyProtocol() {
        require(msg.sender == jAaveAddress, "TrancheDeployer: caller is not JAave");
        _;
    }

    function deployNewTrancheATokens(string memory _nameA, string memory _symbolA, address _sender) external override onlyProtocol returns (address) {
        JTrancheAToken jTrancheA = new JTrancheAToken();
        jTrancheA.initialize(_nameA, _symbolA);
        jTrancheA.setJAaveMinter(msg.sender); 
        jTrancheA.transferOwnership(_sender);
        return address(jTrancheA);
    }

    function deployNewTrancheBTokens(string memory _nameB, string memory _symbolB, address _sender) external override onlyProtocol returns (address) {
        JTrancheBToken jTrancheB = new JTrancheBToken();
        jTrancheB.initialize(_nameB, _symbolB);
        jTrancheB.setJAaveMinter(msg.sender);
        jTrancheB.transferOwnership(_sender);
        return address(jTrancheB);
    }

}