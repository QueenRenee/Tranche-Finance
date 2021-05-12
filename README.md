## AaveProtocol usage

a) deploy JTrancheDeployer and JAave contract and initialize them (JAave parameters: address _priceOracle, address _feesCollector, address _tranchesDepl)

b) call setAavePoolAddressProvider(address _aavePool)

c) set JAave address in jTranchesDeployer contract

    setAavePoolAddressProvider: 0x88757f2f99175387aB4C6a4b3067c77A695b0349 on Kovan

d) call addTrancheToProtocol(address _erc20Contract, string memory _nameA, string memory _symbolA, 
            string memory _nameB, string memory _symbolB, uint256 _fixedRpb, uint8 _underlyingDec) to set a new tranche set

    add ETH tranche: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE","0x87b1f4cf9BD63f7BBD3eE1aD04E8F52540349347","Eth Tranche A","ETA","Eth Tranche B","ETB", web3.utils.toWei("0.04", "ether"),"18"  ----> Please read note below here

    add DAI tranche: "0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD","0xdCf0aF9e59C002FA3AA091a46196b37530FD48a8","Dai tranche A","DTA","Dai Tranche B","DTB", web3.utils.toWei("0.03", "ether"),"18"

    add USDT tranche: "0x13512979ADE267AB5100878E2e0f485B568328a4","0xFF3c8bc103682FA918c954E84F5056aB4DD5189d","USDT tranche A","USDTA","USDT Tranche B","USDTB",web3.utils.toWei("0.125", "ether"),"6"

    add USDC tranche: "0xe22da380ee6B445bb8273C81944ADEB6E8450422","0xe12AFeC5aa12Cf614678f9bFeeB98cA9Bb95b5B0","USDC tranche A","USDCA","USDC Tranche B","USDCB",web3.utils.toWei("0.02", "ether"),"6"


Users can now call buy and redeem functions for tranche A & B tokens

Note: if ETH tranche is deployed, please deploy WETHGateway contract without a proxy, then set its address in JAave with setWETHGatewayAddress function.



## Contracts Size (main contracts, no interfaces, no test contracts)
Limit is 24 KiB for single contract
<table>
    <thead>
      <tr>
        <th>Contract</th>
        <th>Size</th>
      </tr>
    </thead>
    <tbody>
        <tr>
            <td>JAave</td>
            <td><code>18.26 KiB</code></td>
        </tr>
        <tr>
            <td>JAaveStorage</td>
            <td><code>1.66 KiB</code></td>
        </tr>
        <tr>
            <td>JTrancheAToken</td>
            <td><code>7.71 KiB</code></td>
        </tr>
        <tr>
            <td>JTrancheBToken</td>
            <td><code>7.71 KiB</code></td>
        </tr>
        <tr>
            <td>JTranchesDeployer</td>
            <td><code>18.62 KiB</code></td>
        </tr>
        <tr>
            <td>WETHGateway</td>
            <td><code>2.72 KiB</code></td>
        </tr>
    </tbody>
  </table>
