// SPDX-License-Identifier: MIT
/**
 * Created on 2021-02-11
 * @summary: Jibrel Aave Tranche Protocol
 * @author: Jibrel Team
 */
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2; // needed for getAllAtokens and getAllReservesTokens

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IAaveProtocolDataProvider.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./TransferETHHelper.sol";
import "./IJPriceOracle.sol";
import "./IJTrancheTokens.sol";
import "./IJTranchesDeployer.sol";
import "./JAaveStorage.sol";
import "./IJAave.sol";
import "./TokenInterface.sol";


contract JAave is OwnableUpgradeSafe, JAaveStorage, IJAave {
    using SafeMath for uint256;

    /**
     * @dev contract initializer
     * @param _priceOracle price oracle address
     * @param _feesCollector fees collector contract address
     * @param _tranchesDepl tranches deployer contract address
     */
    function initialize(address _priceOracle, 
            address _feesCollector, 
            address _tranchesDepl) public initializer() {
        OwnableUpgradeSafe.__Ownable_init();
        priceOracleAddress = _priceOracle;
        feesCollectorAddress = _feesCollector;
        tranchesDeployerAddress = _tranchesDepl;
        redeemTimeout = 10; //default
        totalBlocksPerYear = 2372500;
    }

    /**
     * @dev admins modifiers
     */
    modifier onlyAdmins() {
        require(IJPriceOracle(priceOracleAddress).isAdmin(msg.sender), "JAave: not an Admin");
        _;
    }

    /**
     * @dev locked modifiers
     */
    modifier locked() {
        require(!fLock);
        fLock = true;
        _;
        fLock = false;
    }

    fallback() external payable {}
    receive() external payable {}

    /**
     * @dev set new addresses for price oracle, fees collector and tranche deployer 
     * @param _priceOracle price oracle address
     * @param _feesCollector fees collector contract address
     * @param _tranchesDepl tranches deployer contract address
     */
    function setNewEnvironment(address _priceOracle, 
            address _feesCollector, 
            address _tranchesDepl) external onlyOwner{
        require((_priceOracle != address(0)) && (_feesCollector != address(0)) && (_tranchesDepl != address(0)), "JAave: check addresses");
        priceOracleAddress = _priceOracle;
        feesCollectorAddress = _feesCollector;
        tranchesDeployerAddress = _tranchesDepl;
    }

    /**
     * @dev set how many blocks will be produced per year on the blockchain 
     * @param _newValue new value
     */
    function setBlocksPerYear(uint256 _newValue) external onlyAdmins {
        totalBlocksPerYear = _newValue;
    }

    /**
     * @dev set Aave Pool Address Provider
     * @param _addressProviderContract aave lending pool address provider contract address (kovan: 0x88757f2f99175387aB4C6a4b3067c77A695b0349)
     */
    function setAavePoolAddressProvider(address _addressProviderContract) external onlyAdmins {
        lendingPoolAddressProvider = _addressProviderContract;
    }

    /**
     * @dev get Aave Pool Address Provider starting from lending pool address provider
     */
    function getDataProvider() public view returns(IAaveProtocolDataProvider) {
        require(lendingPoolAddressProvider != address(0), "JAave: set lending pool address provider");
        return IAaveProtocolDataProvider(ILendingPoolAddressesProvider(lendingPoolAddressProvider)
                    .getAddress(0x0100000000000000000000000000000000000000000000000000000000000000));
    }

    /**
     * @dev get Aave all tokens
     */
    function getAllATokens() external view returns(IAaveProtocolDataProvider.TokenData[] memory) {
        require(lendingPoolAddressProvider != address(0), "JAave: set lending pool address provider");
        IAaveProtocolDataProvider aaveProtocolDataProvider = getDataProvider();
        return aaveProtocolDataProvider.getAllATokens();
    }

    /**
     * @dev get Aave all reserved tokens
     */
    function getAllReservesTokens() external view returns(IAaveProtocolDataProvider.TokenData[] memory) {
        require(lendingPoolAddressProvider != address(0), "JAave: set lending pool address provider");
        IAaveProtocolDataProvider aaveProtocolDataProvider = getDataProvider();
        return aaveProtocolDataProvider.getAllReservesTokens();
    }

    /**
     * @dev get Aave reserve Data for an asset
     * liquidityRate is the return percentage for that asset (multiply by 10^27)
     */
    function getAaveReserveData(uint256 _trancheNum) external view returns(uint256 availableLiquidity, uint256 totalStableDebt,
            uint256 totalVariableDebt, uint256 liquidityRate, uint256 variableBorrowRate, uint256 stableBorrowRate,
            uint256 averageStableBorrowRate, uint256 liquidityIndex, uint256 variableBorrowIndex,
            uint40 lastUpdateTimestamp) {
        require(lendingPoolAddressProvider != address(0), "JAave: set lending pool address provider");
        IAaveProtocolDataProvider aaveProtocolDataProvider = getDataProvider();
        address asset = trancheAddresses[_trancheNum].buyerCoinAddress;
        if (trancheAddresses[_trancheNum].buyerCoinAddress == ETH_ADDR)
            asset = WETH_ADDRESS;
        return aaveProtocolDataProvider.getReserveData(asset);
    }

    function getLendingPool() external view returns (address) {
        return ILendingPoolAddressesProvider(lendingPoolAddressProvider).getLendingPool();
    }
/*
    /**
     *  @notice User deposits tokens to the Aave protocol
     *  @dev User needs to approve the DSProxy to pull the _tokenAddr tokens
     *  @param _tokenAddr The address of the token to be deposited
     *  @param _amount Amount of tokens to be deposited
     */
/*    function aaveDeposit(address _tokenAddr, uint256 _amount) public payable {
        address lendingPool = ILendingPoolAddressesProvider(lendingPoolAddressProvider).getLendingPool();

        if (_tokenAddr == ETH_ADDR) {
            require(msg.value == _amount);
            TokenInterface(WETH_ADDRESS).deposit{value: _amount}();
            _tokenAddr = WETH_ADDRESS;
        } else {
            SafeERC20.safeTransferFrom(IERC20(_tokenAddr), msg.sender, address(this), _amount);
        }

        SafeERC20.safeApprove(IERC20(_tokenAddr), lendingPool, _amount);
        ILendingPool(lendingPool).deposit(_tokenAddr, _amount, address(this), AAVE_REFERRAL_CODE);
    }
*/
    function changeToWeth(address _token) private pure returns(address) {
        if (_token == ETH_ADDR) {
            return WETH_ADDRESS;
        }
        return _token;
    }

    /** 
     * @dev User withdraws tokens from the Aave protocol
     * @param _tokenAddr The address of the token to be withdrawn
     * @param _amount Amount of tokens to be withdrawn
     * @param _to receiver address
     */ 
    function aaveWithdraw(address _tokenAddr, uint256 _amount, address _to) internal {
        address lendingPool = ILendingPoolAddressesProvider(lendingPoolAddressProvider).getLendingPool();
        _tokenAddr = changeToWeth(_tokenAddr);

        uint256 oldBalance;
        uint256 newBalance;
        if (_tokenAddr == WETH_ADDRESS) {
            // get eth balance
            oldBalance = getEthBalance();
            // if weth, pull to proxy and return ETH to user
            ILendingPool(lendingPool).withdraw(_tokenAddr, _amount, address(this));
            // from Weth to Eth, all the Weth balance --> no Weth in contract
            TokenInterface(WETH_ADDRESS).withdraw(IERC20(WETH_ADDRESS).balanceOf(address(this)));
            // get new eth balance
            newBalance = getEthBalance();
            if (newBalance > oldBalance)
                TransferETHHelper.safeTransferETH(_to, _amount);
        } else {
            // if not eth send directly to user
            ILendingPool(lendingPool).withdraw(_tokenAddr, _amount, _to);
        }
    }

    /**
     * @dev check if a cToken is allowed or not
     * @param _trancheNum tranche number
     * @param _aTokenDec cToken decimals
     * @param _underlyingDec underlying token decimals
     */
    function setDecimals(uint256 _trancheNum, uint8 _aTokenDec, uint8 _underlyingDec) external onlyAdmins {
        require((_aTokenDec <= 18) && (_underlyingDec <= 18), "JAave: too many decimals");
        trancheParameters[_trancheNum].aTokenDecimals = _aTokenDec;
        trancheParameters[_trancheNum].underlyingDecimals = _underlyingDec;
    }

    /**
     * @dev set tranche redemption percentage
     * @param _trancheNum tranche number
     * @param _redeemPercent user redemption percent
     */
    function setTrancheRedemptionPercentage(uint256 _trancheNum, uint16 _redeemPercent) external onlyAdmins {
        trancheParameters[_trancheNum].redemptionPercentage = _redeemPercent;
    }

    /**
     * @dev set redemption timeout
     * @param _blockNum timeout (in block numbers)
     */
    function setRedemptionTimeout(uint32 _blockNum) external onlyAdmins {
        redeemTimeout = _blockNum;
    }

    function addTrancheToProtocol(address _buyerCoinAddress, 
            address _aTokenAddress, 
            string memory _nameA, 
            string memory _symbolA, 
            string memory _nameB, 
            string memory _symbolB, 
            uint256 _fixedRpb, 
            uint8 _aTokenDec, 
            uint8 _underlyingDec) external onlyAdmins locked {
        require(tranchesDeployerAddress != address(0), "JAave: set tranche eth deployer");
        require(lendingPoolAddressProvider != address(0), "JAave: set lending pool address provider");

        trancheAddresses[tranchePairsCounter].buyerCoinAddress = _buyerCoinAddress;
        trancheAddresses[tranchePairsCounter].aTokenAddress = _aTokenAddress;
        trancheAddresses[tranchePairsCounter].ATrancheAddress = 
                IJTranchesDeployer(tranchesDeployerAddress).deployNewTrancheATokens(_nameA, _symbolA, msg.sender);
        trancheAddresses[tranchePairsCounter].BTrancheAddress = 
                IJTranchesDeployer(tranchesDeployerAddress).deployNewTrancheBTokens(_nameB, _symbolB, msg.sender); 
        

        trancheParameters[tranchePairsCounter].aTokenDecimals = _aTokenDec;
        trancheParameters[tranchePairsCounter].underlyingDecimals = _underlyingDec;
        trancheParameters[tranchePairsCounter].trancheAFixedPercentage = _fixedRpb;
        trancheParameters[tranchePairsCounter].trancheALastActionBlock = block.number;
        trancheParameters[tranchePairsCounter].storedTrancheAPrice = uint256(1e18);

        trancheParameters[tranchePairsCounter].redemptionPercentage = 9950;  //default value 99.5%

        emit TrancheAddedToProtocol(tranchePairsCounter, trancheAddresses[tranchePairsCounter].ATrancheAddress, trancheAddresses[tranchePairsCounter].BTrancheAddress);

        tranchePairsCounter = tranchePairsCounter.add(1);
    } 

    /**
     * @dev get Tranche A exchange rate
     * @param _trancheNum tranche number
     * @return tranche A token current price
     */
    function setTrancheAExchangeRate(uint256 _trancheNum) public returns (uint256) {
        calcRPBFromPercentage(_trancheNum);
        trancheParameters[_trancheNum].storedTrancheAPrice = (trancheParameters[_trancheNum].storedTrancheAPrice)
                .add( ( trancheParameters[_trancheNum].trancheACurrentRPB).mul( (block.number).sub(trancheParameters[_trancheNum].trancheALastActionBlock) ));
        return trancheParameters[_trancheNum].storedTrancheAPrice;
    }

    /**
     * @dev get Tranche A exchange rate
     * @param _trancheNum tranche number
     * @return tranche A token current price
     */
    function getTrancheAExchangeRate(uint256 _trancheNum) public view returns (uint256) {
        return trancheParameters[_trancheNum].storedTrancheAPrice;
    }

    /**
     * @dev get RPB for a given percentage (expressed in 1e18)
     * @param _trancheNum tranche number
     * @return RPB for a fixed percentage
     */
    function getTrancheACurrentRPB(uint256 _trancheNum) external view returns (uint256) {
        return trancheParameters[_trancheNum].trancheACurrentRPB;
    }

    /**
     * @dev get Tranche A exchange rate
     * @param _trancheNum tranche number
     * @return tranche A token current price
     */
    function calcRPBFromPercentage(uint256 _trancheNum) public returns (uint256) {
        trancheParameters[_trancheNum].trancheACurrentRPB = trancheParameters[_trancheNum].storedTrancheAPrice
                        .mul(trancheParameters[_trancheNum].trancheAFixedPercentage).div(totalBlocksPerYear).div(1e18);
        //trancheParameters[_trancheNum].trancheALastActionBlock = block.number;
        return trancheParameters[_trancheNum].trancheACurrentRPB;
    }

    /**
     * @dev get Tranche A value
     * @param _trancheNum tranche number
     * @return tranche A value
     */
    function getTrAValue(uint256 _trancheNum) public view returns (uint256) {
        uint256 totASupply = IERC20(trancheAddresses[_trancheNum].ATrancheAddress).totalSupply();
        return totASupply.mul(getTrancheAExchangeRate(_trancheNum)).div(10 ** uint256(trancheParameters[_trancheNum].underlyingDecimals));
    }

    /**
     * @dev get Tranche B value
     * @param _trancheNum tranche number
     * @return tranche B value
     */
    function getTrBValue(uint256 _trancheNum) public view returns (uint256) {
        uint256 totProtValue = getTotalValue(_trancheNum);
        uint256 totTrAValue = getTrAValue(_trancheNum);
        if (totProtValue > totTrAValue) {
            return totProtValue.sub(totTrAValue);
        } else
            return 0;
    }

    /**
     * @dev get Tranche total value
     * @param _trancheNum tranche number
     * @return tranche total value
     */
    function getTotalValue(uint256 _trancheNum) public view returns (uint256) {
        return getTokenBalance(trancheAddresses[_trancheNum].aTokenAddress);
    }

    /**
     * @dev get Tranche B exchange rate
     * @param _trancheNum tranche number
     * @param _newAmount new amount entering tranche B
     * @return tbPrice tranche B token current price
     */
    function getTrancheBExchangeRate(uint256 _trancheNum, uint256 _newAmount) public view returns (uint256 tbPrice) {
        // set amount of tokens to be minted via taToken price
        // Current tbDai price = ((aDai-(aSupply X taPrice)) / bSupply)
        // where: aDai = How much aDai we hold in the protocol
        // aSupply = Total number of taDai in protocol
        // taPrice = taDai / Dai price
        // bSupply = Total number of tbDai in protocol
        uint256 totTrBValue;

        uint256 totBSupply = IERC20(trancheAddresses[_trancheNum].BTrancheAddress).totalSupply();
        uint256 newBSupply = totBSupply.add(_newAmount);

        uint256 totProtValue = getTotalValue(_trancheNum).add(_newAmount);
        uint256 totTrAValue = getTrAValue(_trancheNum);
        if (totProtValue >= totTrAValue)
            totTrBValue = totProtValue.sub(totTrAValue);
        else
            totTrBValue = 0;

        if (totTrBValue > 0 && newBSupply > 0) {
            tbPrice = totTrBValue.mul(10 ** uint256(trancheParameters[_trancheNum].underlyingDecimals)).div(newBSupply);
        } else
            tbPrice = 10 ** uint256(trancheParameters[_trancheNum].underlyingDecimals);

        return tbPrice;
    }

    /**
     * @dev buy Tranche A Tokens
     * @param _trancheNum tranche number
     * @param _amount amount of stable coins sent by buyer
     */
    function buyTrancheAToken(uint256 _trancheNum, uint256 _amount) external payable locked {
        uint256 prevAaveTokenBalance = getTokenBalance(trancheAddresses[_trancheNum].aTokenAddress);

        //aaveDeposit(trancheAddresses[_trancheNum].buyerCoinAddress, _amount);
        address lendingPool = ILendingPoolAddressesProvider(lendingPoolAddressProvider).getLendingPool();
        address _tokenAddr = trancheAddresses[_trancheNum].buyerCoinAddress;
        if (_tokenAddr == ETH_ADDR) {
            require(msg.value == _amount, "JAave: msg.value not equal to amount");
            TokenInterface(WETH_ADDRESS).deposit{value: _amount}();
            _tokenAddr = WETH_ADDRESS;
        } else {
            SafeERC20.safeTransferFrom(IERC20(_tokenAddr), msg.sender, address(this), _amount);
        }

        SafeERC20.safeApprove(IERC20(_tokenAddr), lendingPool, _amount);
        ILendingPool(lendingPool).deposit(_tokenAddr, _amount, address(this), AAVE_REFERRAL_CODE);
        
        uint256 newAaveTokenBalance = getTokenBalance(trancheAddresses[_trancheNum].aTokenAddress);
        setTrancheAExchangeRate(_trancheNum);
        uint256 taAmount;
        if (newAaveTokenBalance > prevAaveTokenBalance) {
            // set amount of tokens to be minted calculate taToken amount via taToken price
            taAmount = _amount.mul(10 ** uint256(trancheParameters[_trancheNum].underlyingDecimals)).div(setTrancheAExchangeRate(_trancheNum));
            //Mint trancheA tokens and send them to msg.sender;
            IJTrancheTokens(trancheAddresses[_trancheNum].ATrancheAddress).mint(msg.sender, taAmount);
        }

        lastActivity[msg.sender] = block.number;
        trancheParameters[_trancheNum].trancheALastActionBlock = block.number;
        emit TrancheATokenMinted(_trancheNum, msg.sender, _amount, taAmount);
    }

    /**
     * @dev redeem Tranche A Tokens
     * @param _trancheNum tranche number
     * @param _amount amount of stable coins sent by buyer
     */
    function redeemTrancheAToken(uint256 _trancheNum, uint256 _amount) external locked {
        require((block.number).sub(lastActivity[msg.sender]) >= redeemTimeout, "JAave: redeem timeout not expired on tranche A");
        // check approve
        require(IERC20(trancheAddresses[_trancheNum].ATrancheAddress).allowance(msg.sender, address(this)) >= _amount, "JAave: allowance failed redeeming tranche A");
        //Transfer DAI from msg.sender to protocol;
        SafeERC20.safeTransferFrom(IERC20(trancheAddresses[_trancheNum].ATrancheAddress), msg.sender, address(this), _amount);

        setTrancheAExchangeRate(_trancheNum);
        uint256 taAmount = _amount.mul(trancheParameters[_trancheNum].storedTrancheAPrice).div(10 ** uint256(trancheParameters[_trancheNum].underlyingDecimals));
        // not sure about this
        uint256 taTotAmount = getTrAValue(_trancheNum);
        if (taAmount > taTotAmount)
            taAmount = taTotAmount;

        uint256 userAmount = taAmount.mul(trancheParameters[_trancheNum].redemptionPercentage).div(PERCENT_DIVIDER);
        aaveWithdraw(trancheAddresses[_trancheNum].buyerCoinAddress, userAmount, msg.sender);
        uint256 feesAmount = taAmount.sub(userAmount);
        aaveWithdraw(trancheAddresses[_trancheNum].buyerCoinAddress, feesAmount, feesCollectorAddress);
        
        IJTrancheTokens(trancheAddresses[_trancheNum].ATrancheAddress).burn(_amount);
        lastActivity[msg.sender] = block.number;
        trancheParameters[_trancheNum].trancheALastActionBlock = block.number;
        emit TrancheATokenRedemption(_trancheNum, msg.sender, _amount, userAmount, feesAmount);
    }

    /**
     * @dev buy Tranche B Tokens
     * @param _trancheNum tranche number
     * @param _amount amount of stable coins sent by buyer
     */
    function buyTrancheBToken(uint256 _trancheNum, uint256 _amount) external payable locked {
        // refresh value for tranche A
        setTrancheAExchangeRate(_trancheNum);
        // get tranche B exchange rate
        uint256 tbAmount = _amount.mul(10 ** uint256(trancheParameters[_trancheNum].underlyingDecimals)).div(getTrancheBExchangeRate(_trancheNum, _amount));
        uint256 prevAaveTokenBalance = getTokenBalance(trancheAddresses[_trancheNum].aTokenAddress);
        //aaveDeposit(trancheAddresses[_trancheNum].buyerCoinAddress, _amount);
        address lendingPool = ILendingPoolAddressesProvider(lendingPoolAddressProvider).getLendingPool();
        address _tokenAddr = trancheAddresses[_trancheNum].buyerCoinAddress;
        if (_tokenAddr == ETH_ADDR) {
            require(msg.value == _amount, "JAave: msg.value not equal to amount");
            TokenInterface(WETH_ADDRESS).deposit{value: _amount}();
            _tokenAddr = WETH_ADDRESS;
        } else {
            SafeERC20.safeTransferFrom(IERC20(_tokenAddr), msg.sender, address(this), _amount);
        }

        SafeERC20.safeApprove(IERC20(_tokenAddr), lendingPool, _amount);
        ILendingPool(lendingPool).deposit(_tokenAddr, _amount, address(this), AAVE_REFERRAL_CODE);

        uint256 newAaveTokenBalance = getTokenBalance(trancheAddresses[_trancheNum].aTokenAddress);
        if (newAaveTokenBalance > prevAaveTokenBalance) {
            //Mint trancheB tokens and send them to msg.sender;
            IJTrancheTokens(trancheAddresses[_trancheNum].BTrancheAddress).mint(msg.sender, tbAmount);
        } else 
            tbAmount = 0;

        lastActivity[msg.sender] = block.number;
        emit TrancheBTokenMinted(_trancheNum, msg.sender, _amount, tbAmount);
    }

    /**
     * @dev redeem Tranche B Tokens
     * @param _trancheNum tranche number
     * @param _amount amount of stable coins sent by buyer
     */
    function redeemTrancheBToken(uint256 _trancheNum, uint256 _amount) external locked {
        require((block.number).sub(lastActivity[msg.sender]) >= redeemTimeout, "JAave: redeem timeout not expired on tranche B");
        // check approve
        require(IERC20(trancheAddresses[_trancheNum].BTrancheAddress).allowance(msg.sender, address(this)) >= _amount, "JAave: allowance failed redeeming tranche B");
        //Transfer DAI from msg.sender to protocol;
        SafeERC20.safeTransferFrom(IERC20(trancheAddresses[_trancheNum].BTrancheAddress), msg.sender, address(this), _amount);

        // update tranche A price
        setTrancheAExchangeRate(_trancheNum);
        // get tranche B exchange rate
        uint256 tbAmount = _amount.mul(getTrancheBExchangeRate(_trancheNum, 0)).div(10 ** uint256(trancheParameters[_trancheNum].underlyingDecimals));
        // not sure about this
        uint256 tbTotAmount = getTrBValue(_trancheNum);
        if (tbAmount > tbTotAmount)
            tbAmount = tbTotAmount;

        uint256 userAmount = tbAmount.mul(trancheParameters[_trancheNum].redemptionPercentage).div(PERCENT_DIVIDER);
        aaveWithdraw(trancheAddresses[_trancheNum].buyerCoinAddress, userAmount, msg.sender);
        uint256 feesAmount = tbAmount.sub(userAmount);
        aaveWithdraw(trancheAddresses[_trancheNum].buyerCoinAddress, feesAmount, feesCollectorAddress);

        IJTrancheTokens(trancheAddresses[_trancheNum].BTrancheAddress).burn(_amount);
        lastActivity[msg.sender] = block.number;
        emit TrancheBTokenRedemption(_trancheNum, msg.sender, _amount, userAmount, feesAmount);
    }

    /**
     * @dev get every token balance in this contract
     * @param _tokenContract token contract address
     */
    function getTokenBalance(address _tokenContract) public view returns (uint256) {
        return IERC20(_tokenContract).balanceOf(address(this));
    }

    /**
     * @dev get eth balance on this contract
     */
    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev transfer tokens in this contract to fees collector contract
     * @param _tokenContract token contract address
     * @param _amount token amount to be transferred 
     */
    function transferTokenToOwner(address _tokenContract, uint256 _amount) external onlyAdmins {
        SafeERC20.safeTransfer(IERC20(_tokenContract), feesCollectorAddress, _amount);
    }

    /**
     * @dev transfer ethers in this contract to fees collector contract
     * @param _amount ethers amount to be transferred 
     */
    function withdrawEthToOwner(uint256 _amount) external onlyAdmins {
        TransferETHHelper.safeTransferETH(feesCollectorAddress, _amount);
    }

}