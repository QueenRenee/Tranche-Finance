const {
    deployProxy,
    upgradeProxy
  } = require('@openzeppelin/truffle-upgrades');
  const {
    accounts,
    contract,
    web3
  } = require('@openzeppelin/test-environment');
  const {
    BN,
    constants,
    expectEvent,
    expectRevert
  } = require('@openzeppelin/test-helpers');
  const {
    expect
  } = require('chai');
  const {
    ZERO_ADDRESS
  } = constants;

  const ETH_ADDR = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
  
  const myERC20 = contract.fromArtifact("myERC20");
  const aToken = contract.fromArtifact("myATokenMock");
  const weth9 = contract.fromArtifact("WETH9");
  const lendingPool = contract.fromArtifact("LendingPool");

  const JPriceOracle = contract.fromArtifact('JPriceOracle');
  const JFeesCollector = contract.fromArtifact('JFeesCollector');
  
  const JAave = contract.fromArtifact('JAave');
  const JTranchesDeployer = contract.fromArtifact('JTranchesDeployer');
  
  const JTrancheAToken = contract.fromArtifact('JTrancheAToken');
  const JTrancheBToken = contract.fromArtifact('JTrancheBToken');
  
  const MYERC20_TOKEN_SUPPLY = 5000000;
  const MYATOKEN_SUPPLY = 5000000;
  const GAS_PRICE = 27000000000;
  
  
  function deployMinimumFactory(tokenOwner, factoryOwner, factoryAdmin) {
  
    it('deploys DAI mockup', async function () {
      //gasPrice = await web3.eth.getGasPrice();
      //console.log("Gas price: " + gasPrice);
      console.log("TokenOwner address: " + tokenOwner);
      this.DAI = await myERC20.new({
        from: tokenOwner
      });
      expect(this.DAI.address).to.be.not.equal(ZERO_ADDRESS);
      expect(this.DAI.address).to.match(/0x[0-9a-fA-F]{40}/);
      console.log(`DAI Address: ${this.DAI.address}`);
      result = await this.DAI.totalSupply();
      expect(result.toString()).to.be.equal(new BN(0).toString());
      console.log("DAI total supply: " + result);
      tx = await web3.eth.getTransactionReceipt(this.DAI.transactionHash);
      console.log("DAI contract deploy Gas: " + tx.gasUsed);
      //totcost = tx.gasUsed * GAS_PRICE;
      //console.log("ERC20 Coll1 deploy costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      result = await this.DAI.owner();
      expect(result).to.be.equal(ZERO_ADDRESS);
      tx = await this.DAI.initialize(MYERC20_TOKEN_SUPPLY, {
        from: tokenOwner
      });
      console.log("DAI contract Initialize Gas: " + tx.receipt.gasUsed);
      // totcost = tx.receipt.gasUsed * GAS_PRICE;
      // console.log("ERC20 Coll1 Initialize costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      result = await this.DAI.owner();
      expect(result).to.be.equal(tokenOwner);
      console.log("DAI owner address: " + result);
      borrBal = await this.DAI.balanceOf(tokenOwner);
      console.log(`tokenOwner Balance: ${web3.utils.fromWei(borrBal, "ether")} DAI`);
    });

    it('deploys WETH mockup', async function () {
      //gasPrice = await web3.eth.getGasPrice();
      //console.log("Gas price: " + gasPrice);
      console.log("TokenOwner address: " + tokenOwner);
      this.weth = await weth9.new({
        from: tokenOwner
      });
      expect(this.weth.address).to.be.not.equal(ZERO_ADDRESS);
      expect(this.weth.address).to.match(/0x[0-9a-fA-F]{40}/);
      console.log(`weth Address: ${this.weth.address}`);
      result = await this.weth.totalSupply();
      expect(result.toString()).to.be.equal(new BN(0).toString());
      console.log("weth total supply: " + result);
      tx = await web3.eth.getTransactionReceipt(this.weth.transactionHash);
      console.log("weth contract deploy Gas: " + tx.gasUsed);
      //totcost = tx.gasUsed * GAS_PRICE;
      //console.log("ERC20 Coll1 deploy costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      // totcost = tx.receipt.gasUsed * GAS_PRICE;
      // console.log("ERC20 Coll1 Initialize costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      borrBal = await this.weth.balanceOf(tokenOwner);
      console.log(`tokenOwner Balance: ${web3.utils.fromWei(borrBal, "ether")} weth`);
    });

    it('deploys LendingPool', async function () {
      this.lendingPool = await lendingPool.new({
        from: factoryOwner
      });
      tx = await web3.eth.getTransactionReceipt(this.lendingPool.transactionHash);
      console.log("lendingPool deploy Gas: " + tx.gasUsed);
      // totcost = tx.gasUsed * GAS_PRICE;
      // console.log("JPriceOracle deploy costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      expect(this.lendingPool.address).to.be.not.equal(ZERO_ADDRESS);
      expect(this.lendingPool.address).to.match(/0x[0-9a-fA-F]{40}/);
      console.log("lendingPool address: " + this.lendingPool.address);
      tx = await this.lendingPool.initialize({
        from: factoryOwner
      });
      console.log("lendingPool Initialize Gas: " + tx.receipt.gasUsed);
      // totcost = tx.receipt.gasUsed * GAS_PRICE;
      // console.log("JPriceOracle Initialize costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      result = await this.lendingPool.owner();
      expect(result).to.be.equal(factoryOwner);
      console.log("lendingPool owner address: " + result);
    });
  
    it('deploys aToken mockup', async function () {
      //gasPrice = await web3.eth.getGasPrice();
      //console.log("Gas price: " + gasPrice);
      console.log("TokenOwner address: " + tokenOwner);
/*
      LendingPool pool,
    address underlyingAssetAddress,
    address reserveTreasury,
    string memory tokenName,
    string memory tokenSymbol,
    address incentivesController
    */
      this.aToken = await aToken.new(ETH_ADDR, ETH_ADDR, ETH_ADDR, "aWETH", "aWETH", ETH_ADDR, {
        from: tokenOwner
      });
      expect(this.aToken.address).to.be.not.equal(ZERO_ADDRESS);
      expect(this.aToken.address).to.match(/0x[0-9a-fA-F]{40}/);
      console.log(`Coll Token Address: ${this.aToken.address}`);
  
      tx = await web3.eth.getTransactionReceipt(this.aToken.transactionHash);
      console.log("CEther contract deploy Gas: " + tx.gasUsed);
      //totcost = tx.gasUsed * GAS_PRICE;
      //console.log("ERC20 Coll1 deploy costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      /*uint8 _underlyingAssetDecimals,
    string calldata _tokenName,
    string calldata _tokenSymbol*/
      tx = await this.aToken.initialize(18, "WETH", "WETH",{
        from: tokenOwner
      });
      console.log("CEther contract Initialize Gas: " + tx.receipt.gasUsed);
      // totcost = tx.receipt.gasUsed * GAS_PRICE;
      // console.log("ERC20 Coll1 Initialize costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      // result = await this.aToken.owner();
      // expect(result).to.be.equal(tokenOwner);
      // console.log("CEther owner address: " + result);
  
      result = await this.aToken.totalSupply();
      //expect(result.toString()).to.be.equal(new BN(0).toString());
      console.log("CEther total supply: " + result);
    });
  
    it('deploys JFeeCollector', async function () {
      console.log("factoryOwner address: " + factoryOwner);
      this.JFeesCollector = await JFeesCollector.new({
        from: factoryOwner
      })
      tx = await web3.eth.getTransactionReceipt(this.JFeesCollector.transactionHash);
      console.log("JFeesCollector deploy Gas: " + tx.gasUsed);
      // totcost = tx.gasUsed * GAS_PRICE;
      // console.log("JFeesCollector deploy costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      expect(this.JFeesCollector.address).to.be.not.equal(ZERO_ADDRESS);
      expect(this.JFeesCollector.address).to.match(/0x[0-9a-fA-F]{40}/);
      console.log("JFeesCollector address: " + this.JFeesCollector.address);
      tx = await this.JFeesCollector.initialize({
        from: factoryOwner
      });
      console.log("JFeesCollector Initialize Gas: " + tx.receipt.gasUsed);
      // totcost = tx.receipt.gasUsed * GAS_PRICE;
      // console.log("JFeesCollector Initialize costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      result = await this.JFeesCollector.owner();
      expect(result).to.be.equal(factoryOwner);
      console.log("JFeesCollector owner address: " + result);
    });
  
    it('deploys JPriceOracle', async function () {
      this.JPriceOracle = await JPriceOracle.new({
        from: factoryOwner
      });
      tx = await web3.eth.getTransactionReceipt(this.JPriceOracle.transactionHash);
      console.log("JPriceOracle deploy Gas: " + tx.gasUsed);
      // totcost = tx.gasUsed * GAS_PRICE;
      // console.log("JPriceOracle deploy costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      expect(this.JPriceOracle.address).to.be.not.equal(ZERO_ADDRESS);
      expect(this.JPriceOracle.address).to.match(/0x[0-9a-fA-F]{40}/);
      console.log("JPriceOracle address: " + this.JPriceOracle.address);
      tx = await this.JPriceOracle.initialize({
        from: factoryOwner
      });
      console.log("JPriceOracle Initialize Gas: " + tx.receipt.gasUsed);
      // totcost = tx.receipt.gasUsed * GAS_PRICE;
      // console.log("JPriceOracle Initialize costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      result = await this.JPriceOracle.owner();
      expect(result).to.be.equal(factoryOwner);
      console.log("JPriceOracle owner address: " + result);
    });
  
    it('set new admin in Price oracle contract', async function () {
      tx = await this.JPriceOracle.addAdmin(factoryAdmin, {
        from: factoryOwner
      });
      // console.log(tx.receipt.gasUsed);
      // totcost = tx.gasUsed * GAS_PRICE;
      // console.log("New admin costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      expect(await this.JPriceOracle.isAdmin(factoryAdmin)).to.be.true;
    });
  
    it('deploys Tranches Deployer', async function () {
      console.log("TokenOwner address: " + factoryOwner);
      this.JTranchesDeployer = await JTranchesDeployer.new({
        from: factoryOwner
      });
      tx = await web3.eth.getTransactionReceipt(this.JTranchesDeployer.transactionHash);
      console.log("Tranches Deployer deploy Gas: " + tx.gasUsed);
      expect(this.JTranchesDeployer.address).to.be.not.equal(ZERO_ADDRESS);
      expect(this.JTranchesDeployer.address).to.match(/0x[0-9a-fA-F]{40}/);
      console.log(`Tranches Deployer Address: ${this.JTranchesDeployer.address}`);
      result = await this.JTranchesDeployer.owner();
      expect(result).to.be.equal(ZERO_ADDRESS);
      console.log("Tranches deployer owner: " + result);
      tx = await this.JTranchesDeployer.initialize({
        from: factoryOwner
      });
      console.log("Tranches Deployer Initialize Gas: " + tx.receipt.gasUsed);
      //totcost = tx.gasUsed * GAS_PRICE;
      //console.log("ETH Tranche A deploy costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      result = await this.JTranchesDeployer.owner();
      expect(result).to.be.equal(factoryOwner);
      console.log("Tranches Deployer address: " + result);
    });
  
    it('deploys JAave contract', async function () {
      this.JAave = await JAave.new({
        from: factoryOwner
      });
      expect(this.JAave.address).to.be.not.equal(ZERO_ADDRESS);
      expect(this.JAave.address).to.match(/0x[0-9a-fA-F]{40}/);
      console.log(`JAave Address: ${this.JAave.address}`);
      tx = await web3.eth.getTransactionReceipt(this.JAave.transactionHash);
      console.log("JAave deploy Gas: " + tx.gasUsed);
      //totcost = tx.gasUsed * GAS_PRICE;
      //console.log("ETH Tranche B deploy costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      result = await this.JAave.owner();
      expect(result).to.be.equal(ZERO_ADDRESS);
      tx = await this.JAave.initialize(this.JPriceOracle.address, this.JFeesCollector.address, this.JTranchesDeployer.address, {
        from: factoryOwner
      });
      console.log("JAave Initialize Gas: " + tx.receipt.gasUsed);
      result = await this.JAave.owner();
      expect(result).to.be.equal(factoryOwner);
      console.log("JAave owner address: " + result);
    });
  
    it('set protocol address in tranches deployer', async function () {
      tx = await this.JTranchesDeployer.setJAaveAddress(this.JAave.address, {
        from: factoryOwner
      });
      console.log("JTranchesDeployer set protocol address Gas: " + tx.receipt.gasUsed);
      jcomp = await this.JTranchesDeployer.jAaveAddress();
      expect(jcomp).to.be.equal(this.JAave.address);
    });
  
    it('deploys JAave configuration', async function () {  
      tx = await this.JAave.setAavePoolAddressProvider(ETH_ADDR, {
        from: factoryOwner
      });
      tx = await this.JAave.addTrancheToProtocol(ETH_ADDR, this.aToken.address, "jEthTrancheAToken", "JEA", "jEthTrancheBToken", "JEB", web3.utils.toWei("0.04", "ether"), 18, 18, {
        from: factoryOwner
      });
      trParams = await this.JAave.trancheAddresses(0);
      this.EthTrA = await JTrancheAToken.at(trParams.ATrancheAddress);
      console.log("Eth Tranche A Token Address: " + this.EthTrA.address);
      this.EthTrB = await JTrancheBToken.at(trParams.BTrancheAddress);
      console.log("Eth Tranche B Token Address: " + this.EthTrB.address);
  
      tx = await this.JAave.addTrancheToProtocol(this.DAI.address, this.aToken.address, "jDaiTrancheAToken", "JDA", "jDaiTrancheBToken", "JDB", web3.utils.toWei("0.03", "ether"), 18, 18, {
        from: factoryOwner
      });
      trParams = await this.JAave.trancheAddresses(1);
      this.DaiTrA = await JTrancheAToken.at(trParams.ATrancheAddress);
      console.log("Dai Tranche A Token Address: " + this.DaiTrA.address);
      this.DaiTrB = await JTrancheBToken.at(trParams.BTrancheAddress);
      console.log("Dai Tranche B Token Address: " + this.DaiTrB.address);
    });
  }
  
/*  
  function sendcETHtoProtocol(tokenOwner) {
  
    it('send some DAI to JAave', async function () {
      tx = await this.CEther.transfer(this.JAave.address, web3.utils.toWei('1', 'ether'), {
        from: tokenOwner
      });
      console.log("Gas to transfer DAI to JAave: " + tx.receipt.gasUsed);
      // totcost = tx.receipt.gasUsed * GAS_PRICE;
      // console.log("transfer token costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      protBal = await this.CEther.balanceOf(this.JAave.address);
      console.log(`protocol DAI Balance: ${web3.utils.fromWei(protBal, "ether")} DAI`)
      expect(web3.utils.fromWei(protBal, "ether")).to.be.equal(new BN(1).toString());
    });
  }
  
  
  function sendcDAItoProtocol(tokenOwner) {
  
    it('send some DAI to JAave', async function () {
      tx = await this.CErc20.transfer(this.JAave.address, web3.utils.toWei('10', 'ether'), {
        from: tokenOwner
      });
      console.log("Gas to transfer DAI to JAave: " + tx.receipt.gasUsed);
      // totcost = tx.receipt.gasUsed * GAS_PRICE;
      // console.log("transfer token costs: " + web3.utils.fromWei(totcost.toString(), 'ether') + " ETH");
      protBal = await this.CErc20.balanceOf(this.JAave.address);
      console.log(`protocol DAI Balance: ${web3.utils.fromWei(protBal, "ether")} DAI`)
      expect(web3.utils.fromWei(protBal, "ether")).to.be.equal(new BN(10).toString());
    });
  }
  
*/
  
  function sendDAItoUsers(tokenOwner, user1, user2, user3, user4, user5, user6) {
  
    it('send some DAI to users', async function () {
      tx = await this.DAI.transfer(user1, web3.utils.toWei('100000', 'ether'), {
        from: tokenOwner
      });
      console.log("Gas to transfer DAI to user1: " + tx.receipt.gasUsed);
      userBal = await this.DAI.balanceOf(user1);
      console.log(`user1 DAI Balance: ${web3.utils.fromWei(userBal, "ether")} DAI`)
      expect(web3.utils.fromWei(userBal, "ether")).to.be.equal(new BN(100000).toString());
  
      tx = await this.DAI.transfer(user2, web3.utils.toWei('200000', 'ether'), {
        from: tokenOwner
      });
      console.log("Gas to transfer DAI to user2: " + tx.receipt.gasUsed);
      userBal = await this.DAI.balanceOf(user2);
      console.log(`user2 DAI Balance: ${web3.utils.fromWei(userBal, "ether")} DAI`)
      expect(web3.utils.fromWei(userBal, "ether")).to.be.equal(new BN(200000).toString());
  
      tx = await this.DAI.transfer(user3, web3.utils.toWei('300000', 'ether'), {
        from: tokenOwner
      });
      console.log("Gas to transfer DAI to user3: " + tx.receipt.gasUsed);
      userBal = await this.DAI.balanceOf(user3);
      console.log(`user3 DAI Balance: ${web3.utils.fromWei(userBal, "ether")} DAI`)
      expect(web3.utils.fromWei(userBal, "ether")).to.be.equal(new BN(300000).toString());
  
      tx = await this.DAI.transfer(user4, web3.utils.toWei('400000', 'ether'), {
        from: tokenOwner
      });
      console.log("Gas to transfer DAI to user4: " + tx.receipt.gasUsed);
      userBal = await this.DAI.balanceOf(user4);
      console.log(`user4 DAI Balance: ${web3.utils.fromWei(userBal, "ether")} DAI`)
      expect(web3.utils.fromWei(userBal, "ether")).to.be.equal(new BN(400000).toString());
  
      tx = await this.DAI.transfer(user5, web3.utils.toWei('500000', 'ether'), {
        from: tokenOwner
      });
      console.log("Gas to transfer DAI to user5: " + tx.receipt.gasUsed);
      userBal = await this.DAI.balanceOf(user5);
      console.log(`user5 DAI Balance: ${web3.utils.fromWei(userBal, "ether")} DAI`)
      expect(web3.utils.fromWei(userBal, "ether")).to.be.equal(new BN(500000).toString());
  
      tx = await this.DAI.transfer(user6, web3.utils.toWei('600000', 'ether'), {
        from: tokenOwner
      });
      console.log("Gas to transfer DAI to user6: " + tx.receipt.gasUsed);
      userBal = await this.DAI.balanceOf(user6);
      console.log(`user6 DAI Balance: ${web3.utils.fromWei(userBal, "ether")} DAI`)
      expect(web3.utils.fromWei(userBal, "ether")).to.be.equal(new BN(600000).toString());
    });
  }
  
  
  
  module.exports = {
    deployMinimumFactory,
    //sendcETHtoProtocol,
    //sendcDAItoProtocol,
    sendDAItoUsers
  };