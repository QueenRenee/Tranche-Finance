// SPDX-License-Identifier: MIT
/**
 * Created on 2021-01-16
 * @summary: Jibrel Protocol Storage
 * @author: Jibrel Team
 */
pragma solidity 0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

contract JAaveStorage is OwnableUpgradeSafe {
/* WARNING: NEVER RE-ORDER VARIABLES! Always double-check that new variables are added APPEND-ONLY. Re-ordering variables can permanently BREAK the deployed proxy contract.*/
    //address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // mainnet
    address public constant WETH_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C; // kovan
    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint16 public constant AAVE_REFERRAL_CODE = 0;

    struct TrancheAddresses {
        address buyerCoinAddress;       // ETH (ETH_ADDR) or DAI
        address aTokenAddress;          // aETH or aDAI
        address ATrancheAddress;
        address BTrancheAddress;
    }

    struct TrancheParameters {
        uint256 trancheAFixedPercentage;
        uint256 trancheALastActionBlock;
        uint256 storedTrancheAPrice;
        uint256 trancheACurrentRPB;
        uint16 redemptionPercentage;    // percentage with 2 decimals (divided by 10000, i.e. 95% is 9500)
        uint8 aTokenDecimals;
        uint8 underlyingDecimals;
    }

    address public priceOracleAddress;
    address public feesCollectorAddress;
    address public tranchesDeployerAddress;
    address public lendingPoolAddressProvider;

    uint256 public tranchePairCounter;
    uint256 public totalBlocksPerYear; 
    uint32 public redeemTimeout;

    bool public fLock;

    mapping(uint256 => TrancheAddresses) public trancheAddresses;
    mapping(uint256 => TrancheParameters) public trancheParameters;
    // last block number where the user withdrew/deposited tokens
    mapping(address => uint256) public lastActivity;
}