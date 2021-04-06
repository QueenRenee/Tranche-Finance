require('dotenv').config();
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
//var { abi } = require('../build/contracts/myERC20.json');

var JFeesCollector = artifacts.require("JFeesCollector");
var JPriceOracle = artifacts.require("JPriceOracle");

var JAave = artifacts.require('JAave');
var JTranchesDeployer = artifacts.require('JTranchesDeployer');

var JTrancheAToken = artifacts.require('JTrancheAToken');
var JTrancheBToken = artifacts.require('JTrancheBToken');

module.exports = async (deployer, network, accounts) => {
  //const MYERC20_TOKEN_SUPPLY = 5000000;
  //const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
  //const WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // mainnet
  //const WETH_ADDRESS = '0xd0A1E359811322d97991E03f863a0C30C2cF029C'; // kovan
  const DAI_ADDRESS = '0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD';

  const LendingPoolAddressesProvider = '0x88757f2f99175387aB4C6a4b3067c77A695b0349';
  const aWETH_Address = '0x87b1f4cf9BD63f7BBD3eE1aD04E8F52540349347';
  const aDAI_Address = '0xdCf0aF9e59C002FA3AA091a46196b37530FD48a8';

  if (network == "development") {
    const factoryOwner = accounts[0];
    const JFCinstance = await deployProxy(JFeesCollector, [], { from: factoryOwner });
    console.log('JFeesCollector Deployed: ', JFCinstance.address);

    const JPOinstance = await deployProxy(JPriceOracle, [], { from: factoryOwner });
    console.log('JPriceOracle Deployed: ', JPOinstance.address);

    const JTDeployer = await deployProxy(JTranchesDeployer, [], { from: factoryOwner });
    console.log("Tranches Deployer: " + JTDeployer.address);

    const JAinstance = await deployProxy(JAave, [JPOinstance.address, JFCinstance.address, JTDeployer.address], { from: factoryOwner });
    console.log('JAave Deployed: ', JAinstance.address);

    await JAinstance.setAavePoolAddressProvider(LendingPoolAddressesProvider, { from: factoryOwner })

    await JTDeployer.setJAaveAddress(JAinstance.address, { from: factoryOwner });

    await JAinstance.addTrancheToProtocol(ETH_ADDRESS, aWETH_Address, "jEthTrancheAToken", "JEA", "jEthTrancheBToken", "JEB", web3.utils.toWei("0.04", "ether"), 18, 18, { from: factoryOwner });
    trParams = await JAinstance.trancheAddresses(0);
    let EthTrA = await JTrancheAToken.at(trParams.ATrancheAddress);
    console.log("Eth Tranche A Token Address: " + EthTrA.address);
    let EthTrB = await JTrancheBToken.at(trParams.BTrancheAddress);
    console.log("Eth Tranche B Token Address: " + EthTrB.address);

    await JAinstance.addTrancheToProtocol(DAI_ADDRESS, aDAI_Address, "jDaiTrancheAToken", "JDA", "jDaiTrancheBToken", "JDB", web3.utils.toWei("0.03", "ether"), 18, 18, { from: factoryOwner });
    trParams = await JAinstance.trancheAddresses(1);
    let DaiTrA = await JTrancheAToken.at(trParams.ATrancheAddress);
    console.log("Eth Tranche A Token Address: " + DaiTrA.address);
    let DaiTrB = await JTrancheBToken.at(trParams.BTrancheAddress);
    console.log("Eth Tranche B Token Address: " + DaiTrB.address);

  } else if (network == "kovan") {
    let { FEE_COLLECTOR_ADDRESS, PRICE_ORACLE_ADDRESS, IS_UPGRADE, AAVE_POOL, AWETH_ADDRESS, ADAI_ADDRESS, DAI_ADDRESS } = process.env;
    const accounts = await web3.eth.getAccounts();
    const factoryOwner = accounts[0];
    if (IS_UPGRADE == 'true') {
      console.log('contracts are upgraded');
    } else {
      // deployed new contract
      const aaveDeployer = await deployProxy(JTranchesDeployer, [], { from: factoryOwner });
      console.log(`AAVE_DEPLOYER=${aaveDeployer.address}`);

      const JPOinstance = await deployProxy(JPriceOracle, [], { from: factoryOwner });
      console.log('JPriceOracle Deployed: ', JPOinstance.address);

      const JAaveInstance = await deployProxy(JAave, [JPOinstance.address, FEE_COLLECTOR_ADDRESS, aaveDeployer.address],
        { from: factoryOwner });
      console.log(`AAVE_TRANCHE_ADDRESS=${JAaveInstance.address}`);

      await aaveDeployer.setJAaveAddress(JAaveInstance.address, { from: factoryOwner });
      console.log('compound deployer 1');

      await JAaveInstance.setAavePoolAddressProvider(AAVE_POOL, { from: factoryOwner });
      console.log('compound deployer 2');

      await JAaveInstance.addTrancheToProtocol(DAI_ADDRESS, ADAI_ADDRESS, "Tranche A - AAVE DAI", "AADAI", "Tranche B - AAVE DAI", "BADAI", web3.utils.toWei("0.03", "ether"), 18, 18, { from: factoryOwner });
      console.log('compound deployer 3');

      await JAaveInstance.addTrancheToProtocol(ETH_ADDRESS, AWETH_ADDRESS, "Tranche A - AAVE ETH", "AAETH", "Tranche A - AAVE ETH", "BAETH", web3.utils.toWei("0.04", "ether"), 18, 18, { from: factoryOwner });
      console.log('compound deployer 4');

      console.log(`JAave deployed at: ${JAaveInstance.address}`);
    }
  }
}