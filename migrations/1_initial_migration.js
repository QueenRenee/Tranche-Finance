require('dotenv').config();
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
// var { abi } = require('../build/contracts/myERC20.json');

var JFeesCollector = artifacts.require("./mocks/JFeesCollector.sol");
var JPriceOracle = artifacts.require("./mocks/JPriceOracle.sol");
// var myERC20 = artifacts.require("./mocks/myERC20.sol");

var JAave = artifacts.require('./JAave');
var JTranchesDeployer = artifacts.require('./JTranchesDeployer');

var JTrancheAToken = artifacts.require('./JTrancheAToken');
var JTrancheBToken = artifacts.require('./JTrancheBToken');


module.exports = async (deployer, network, accounts) => {
  const MYERC20_TOKEN_SUPPLY = 5000000;
  //const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
  //const WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // mainnet
  //const WETH_ADDRESS = '0xd0A1E359811322d97991E03f863a0C30C2cF029C'; // kovan
  const DAI_ADDRESS = '0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD';

  const LendingPoolAddressesProvider = '0x88757f2f99175387aB4C6a4b3067c77A695b0349';
  const aWETH_Address = '0x87b1f4cf9BD63f7BBD3eE1aD04E8F52540349347';
  const aDAI_Address = '0xdCf0aF9e59C002FA3AA091a46196b37530FD48a8';

/*
Kovan Network

All tokens:
aAAVE,0x6d93ef8093F067f19d33C2360cE17b20a8c45CD7,
aBAT,0x28f92b4c8Bdab37AF6C4422927158560b4bB446e,
aBUSD,0xfe3E41Db9071458e39104711eF1Fa668bae44e85,
aDAI,0xdCf0aF9e59C002FA3AA091a46196b37530FD48a8,
aENJ,0x1d1F2Cb9ED46A8d5bf0254E5CE400514D62d55F0,
aKNC,0xdDdEC78e29f3b579402C42ca1fd633DE00D23940,
aLINK,0xeD9044cA8F7caCe8eACcD40367cF2bee39eD1b04,
aMANA,0xA288B1767C91Aa9d8A14a65dC6B2E7ce68c02DFd,
aMKR,0x9d9DaBEae6BcBa881404A9e499B13B2B3C1F329E,
aREN,0x01875ee883B32f5f961A92eC597DcEe2dB7589c1,
aSNX,0xAA74AdA92dE4AbC0371b75eeA7b1bd790a69C9e1,
aSUSD,0x9488fF6F29ff75bfdF8cd5a95C6aa679bc7Cd65c,
aTUSD,0x39914AdBe5fDbC2b9ADeedE8Bcd444b20B039204,
aUSDC,0xe12AFeC5aa12Cf614678f9bFeeB98cA9Bb95b5B0,
aUSDT,0xFF3c8bc103682FA918c954E84F5056aB4DD5189d,
aWBTC,0x62538022242513971478fcC7Fb27ae304AB5C29F,
aWETH,0x87b1f4cf9BD63f7BBD3eE1aD04E8F52540349347,
aYFI,0xF6c7282943Beac96f6C70252EF35501a6c1148Fe,
aZRX,0xf02D7C23948c9178C68f5294748EB778Ab5e5D9c,
aUNI,0x601FFc9b7309bdb0132a02a569FBd57d6D1740f2

All reservesTokens:
AAVE,0xB597cd8D3217ea6477232F9217fa70837ff667Af,
BAT,0x2d12186Fbb9f9a8C28B3FfdD4c42920f8539D738,
BUSD,0x4c6E1EFC12FDfD568186b7BAEc0A43fFfb4bCcCf,
DAI,0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD,
ENJ,0xC64f90Cd7B564D3ab580eb20a102A8238E218be2,
KNC,0x3F80c39c0b96A0945f9F0E9f55d8A8891c5671A8,
LINK,0xAD5ce863aE3E4E9394Ab43d4ba0D80f419F61789,
MANA,0x738Dc6380157429e957d223e6333Dc385c85Fec7,
MKR,0x61e4CAE3DA7FD189e52a4879C7B8067D7C2Cc0FA,
REN,0x5eebf65A6746eed38042353Ba84c8e37eD58Ac6f,
SNX,0x7FDb81B0b8a010dd4FFc57C3fecbf145BA8Bd947,
sUSD,0x99b267b9D96616f906D53c26dECf3C5672401282,
TUSD,0x016750AC630F711882812f24Dba6c95b9D35856d,
USDC,0xe22da380ee6B445bb8273C81944ADEB6E8450422,
USDT,0x13512979ADE267AB5100878E2e0f485B568328a4,
WBTC,0xD1B98B6607330172f1D991521145A22BCe793277,
WETH,0xd0A1E359811322d97991E03f863a0C30C2cF029C,
YFI,0xb7c325266ec274fEb1354021D27FA3E3379D840d,
ZRX,0xD0d76886cF8D952ca26177EB7CfDf83bad08C00C,
UNI,0x075A36BA8846C6B6F53644fDd3bf17E5151789DC
*/

  if (network == "development") {
    const tokenOwner = accounts[0];
    // const myDAIinstance = await deployProxy(myERC20, [MYERC20_TOKEN_SUPPLY], { from: tokenOwner });
    // console.log('myDAI Deployed: ', myDAIinstance.address);

    const factoryOwner = accounts[0];
    const JFCinstance = await deployProxy(JFeesCollector, [], { from: factoryOwner });
    console.log('JFeesCollector Deployed: ', JFCinstance.address);

    const JPOinstance = await deployProxy(JPriceOracle, [], { from: factoryOwner });
    console.log('JPriceOracle Deployed: ', JPOinstance.address);

    const JTDeployer = await deployProxy(JTranchesDeployer, [], { from: factoryOwner });
    console.log("Tranches Deployer: " + JTDeployer.address);

    const JAinstance = await deployProxy(JAave, [JPOinstance.address, JFCinstance.address, JTDeployer.address], { from: factoryOwner });
    console.log('JAave Deployed: ', JAinstance.address);

    await JTDeployer.setAavePoolAddressProvider(LendingPoolAddressesProvider, { from: factoryOwner });

    await JAinstance.addTrancheToProtocol(ETH_ADDRESS, aWETH_Address, "jEthTrancheAToken", "JEA", "jEthTrancheBToken", "JEB",  web3.utils.toWei("0.04", "ether"), 18, 18, { from: factoryOwner });
    trParams = await JAinstance.trancheAddresses(0);
    let EthTrA = await JTrancheAToken.at(trParams.ATrancheAddress);
    console.log("Eth Tranche A Token Address: " + EthTrA.address);
    let EthTrB = await JTrancheBToken.at(trParams.BTrancheAddress);
    console.log("Eth Tranche B Token Address: " + EthTrB.address);

    await JAinstance.addTrancheToProtocol(DAI_ADDRESS, aDAI_Address, "jDaiTrancheAToken", "JDA", "jDaiTrancheBToken", "JDB",  web3.utils.toWei("0.03", "ether"), 18, 18, { from: factoryOwner });
    trParams = await JAinstance.trancheAddresses(1);
    let DaiTrA = await JTrancheAToken.at(trParams.ATrancheAddress);
    console.log("Eth Tranche A Token Address: " + DaiTrA.address);
    let DaiTrB = await JTrancheBToken.at(trParams.BTrancheAddress);
    console.log("Eth Tranche B Token Address: " + DaiTrB.address);

  } else if (network == "kovan") {
    let { FEE_COLLECTOR_ADDRESS, PRICE_ORACLE_ADDRESS, IS_UPGRADE, aDAI_Address, DAI_ADDRESS, aWETH_Address } = process.env;
    const accounts = await web3.eth.getAccounts();
    const factoryOwner = accounts[0];
    if (IS_UPGRADE == 'true') {

      console.log('contracts are upgraded');
    } else {
      // deployed new contract
      const aaveDeployer = await deployProxy(JTranchesDeployer, [], { from: factoryOwner, unsafeAllowCustomTypes: true });
      console.log(`AAVE_DEPLOYER=${compoundDeployer.address}`);

      const JPOinstance = await deployProxy(JPriceOracle, [], { from: factoryOwner });
      console.log('JPriceOracle Deployed: ', JPOinstance.address);

      const JAaveInstance = await deployProxy(JAave, [JPOinstance.address, FEE_COLLECTOR_ADDRESS, aaveDeployer.address],
        { from: factoryOwner });

      console.log(`AAVE_TRANCHE_ADDRESS=${JAaveInstance.address}`);
      aaveDeployer.setJAaveAddress(JAaveInstance.address);

      console.log('compound deployer 1');
      await JAaveInstance.setAavePoolAddressProvider(LendingPoolAddressesProvider, { from: factoryOwner });

      console.log('compound deployer 2');
      //await JAaveInstance.setCEtherContract(CETH_ADDRESS, { from: factoryOwner });

      console.log('compound deployer 3');
      await JAaveInstance.addTrancheToProtocol(DAI_ADDRESS, aDAI_Address, "JCD tranche A", "JCDA", "JCD tranche A", "JCDB", web3.utils.toWei("0.03", "ether"), 18, 18, { from: factoryOwner });

      console.log('compound deployer 4');
      await JAaveInstance.addTrancheToProtocol(ETH_ADDRESS, aWETH_Address, "JCE tranche A", "JCEA", "JCE tranche A", "JCEB", web3.utils.toWei("0.04", "ether"), 18, 18, { from: factoryOwner });

      console.log('compound deployer 5');
      console.log(`JAave deployed at: ${JAaveInstance.address}`);
    }
  }
}