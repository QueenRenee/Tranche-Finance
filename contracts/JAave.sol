// SPDX-License-Identifier: MIT
/**
 * Created on 2021-02-11
 * @summary: Jibrel Compound Tranche Deployer
 * @author: Jibrel Team
 */
pragma solidity ^0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./interfaces/IWETHGateway.sol";
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
        require(IJPriceOracle(priceOracleAddress).isAdmin(msg.sender), "Protocol: not an Admin");
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

    // This is needed to receive ETH when calling redeemCEth function
    fallback() external payable {}
    receive() external payable {}

    /**
     * @dev set how many blocks will be produced per year on the blockchain 
     * @param _newValue new value (Compound blocksPerYear = 2102400)
     */
    function setBlocksPerYear(uint256 _newValue) external onlyAdmins {
        totalBlocksPerYear = _newValue;
    }

    /**
     * @dev set Aave Pool
     * @param _trancheNum tranche number
     * @param _addressProviderContract aave pool contract address (kovan: 0x88757f2f99175387aB4C6a4b3067c77A695b0349)
     */
    function setAavePool(uint256 _trancheNum, address payable _addressProviderContract) external onlyAdmins {
        trancheAddresses[_trancheNum].lendingPoolAddressProvider = _addressProviderContract;
    }
/*
    function getDataProvider(address _market) internal view returns(ILendingPoolAddressesProvider) {
        return IAaveProtocolDataProviderV2(ILendingPoolAddressesProvider(_market).getAddress(0x0100000000000000000000000000000000000000000000000000000000000000));
    }

    function setUserUseReserveAsCollateralIfNeeded(address _market, address _tokenAddr) public {
        address lendingPool = ILendingPoolAddressesProvider(_market).getLendingPool();
        IAaveProtocolDataProviderV2 dataProvider = getDataProvider(_market);

        (,,,,,,,,bool collateralEnabled) = dataProvider.getUserReserveData(_tokenAddr, address(this));

        if (!collateralEnabled) {
            ILendingPool(lendingPool).setUserUseReserveAsCollateral(_tokenAddr, true);
        }
    }

/* 
    function makeDeposit() public payable  {
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
        IERC20(dai).approve(provider.getLendingPoolCore(), amount);
        lendingPool.deposit(dai, amount, 0);
    }
*/
    /// @notice User deposits tokens to the Aave protocol
    /// @dev User needs to approve the DSProxy to pull the _tokenAddr tokens
    /// @param _market address provider for specific market
    /// @param _tokenAddr The address of the token to be deposited
    /// @param _amount Amount of tokens to be deposited
    function aaveDeposit(address _market, address _tokenAddr, uint256 _amount) public /*burnGas(5)*/ payable {
        address lendingPool = ILendingPoolAddressesProvider(_market).getLendingPool();

        if (_tokenAddr == ETH_ADDR) {
            require(msg.value == _amount);
            TokenInterface(WETH_ADDRESS).deposit{value: _amount}();
            _tokenAddr = WETH_ADDRESS;
        } else {
            SafeERC20.safeTransferFrom(IERC20(_tokenAddr), msg.sender, address(this), _amount);
        }

        SafeERC20.safeApprove(IERC20(_tokenAddr), lendingPool, uint256(-1));
        ILendingPool(lendingPool).deposit(_tokenAddr, _amount, address(this), AAVE_REFERRAL_CODE);

        //setUserUseReserveAsCollateralIfNeeded(_market, _tokenAddr);
    }

    function changeToWeth(address _token) private pure returns(address) {
        if (_token == ETH_ADDR) {
            return WETH_ADDRESS;
        }

        return _token;
    }

    /// @notice User withdraws tokens from the Aave protocol
    /// @param _market address provider for specific market
    /// @param _tokenAddr The address of the token to be withdrawn
    /// @param _amount Amount of tokens to be withdrawn -> send -1 for whole amount
    function aaveWithdraw(address _market, address _tokenAddr, uint256 _amount) public /*burnGas(8)*/ {
        address lendingPool = ILendingPoolAddressesProvider(_market).getLendingPool();
        _tokenAddr = changeToWeth(_tokenAddr);

        if (_tokenAddr == WETH_ADDRESS) {
            // if weth, pull to proxy and return ETH to user
            ILendingPool(lendingPool).withdraw(_tokenAddr, _amount, address(this));
            // needs to use balance of in case that amount is -1 for whole debt
            TokenInterface(WETH_ADDRESS).withdraw(TokenInterface(WETH_ADDRESS).balanceOf(address(this)));
            msg.sender.transfer(address(this).balance);
        } else {
            // if not eth send directly to user
            ILendingPool(lendingPool).withdraw(_tokenAddr, _amount, msg.sender);
        }
    }

    /**
     * @dev check if a cToken is allowed or not
     * @param _trancheNum tranche number
     * @param _aTokenDec cToken decimals
     * @param _underlyingDec underlying token decimals
     */
    function setDecimals(uint256 _trancheNum, uint8 _aTokenDec, uint8 _underlyingDec) external onlyAdmins {
        trancheParameters[_trancheNum].aTokenDecimals = _aTokenDec;
        trancheParameters[_trancheNum].underlyingDecimals = _underlyingDec;
    }

    /**
     * @dev set tranche redemption percentage
     * @param _trancheNum tranche number
     * @param _redeemPercent user redemption percent
     */
    function setTrancheVaultPercentage(uint256 _trancheNum, uint16 _redeemPercent) external onlyAdmins {
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
        require(tranchesDeployerAddress != address(0), "CProtocol: set tranche eth deployer");

        trancheAddresses[tranchePairCounter].buyerCoinAddress = _buyerCoinAddress;
        trancheAddresses[tranchePairCounter].aTokenAddress = _aTokenAddress;
        trancheAddresses[tranchePairCounter].ATrancheAddress = 
                IJTranchesDeployer(tranchesDeployerAddress).deployNewTrancheATokens(_nameA, _symbolA, msg.sender);
        trancheAddresses[tranchePairCounter].BTrancheAddress = 
                IJTranchesDeployer(tranchesDeployerAddress).deployNewTrancheBTokens(_nameB, _symbolB, msg.sender); 
        

        trancheParameters[tranchePairCounter].aTokenDecimals = _aTokenDec;
        trancheParameters[tranchePairCounter].underlyingDecimals = _underlyingDec;
        trancheParameters[tranchePairCounter].trancheAFixedPercentage = _fixedRpb;
        trancheParameters[tranchePairCounter].trancheALastActionBlock = block.number;
        trancheParameters[tranchePairCounter].storedTrancheAPrice = uint256(1e18); //getCompoundPrice(tranchePairCounter);

        trancheParameters[tranchePairCounter].redemptionPercentage = 9950;  //default value 99.5%

        emit TrancheAddedToProtocol(tranchePairCounter, trancheAddresses[tranchePairCounter].ATrancheAddress, trancheAddresses[tranchePairCounter].BTrancheAddress);

        tranchePairCounter = tranchePairCounter.add(1);
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
    function getTrBValue(uint256 _trancheNum) external view returns (uint256) {
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
        //uint256 compPrice = getCompoundPrice(_trancheNum);
        uint256 compPrice = 1;
        uint256 totProtSupply = getTokenBalance(trancheAddresses[_trancheNum].aTokenAddress);
        return totProtSupply.mul(compPrice).div(10 ** uint256(trancheParameters[_trancheNum].aTokenDecimals));
    }

    /**
     * @dev get Tranche B exchange rate
     * @param _trancheNum tranche number
     * @param _newAmount new amount entering tranche B
     * @return tbPrice tranche B token current price
     */
    function getTrancheBExchangeRate(uint256 _trancheNum, uint256 _newAmount) public view returns (uint256 tbPrice) {
        // set amount of tokens to be minted via taToken price
        // Current tbDai price = (((cDai X cPrice)-(aSupply X taPrice)) / bSupply)
        // where: cDai = How much cDai we hold in the protocol
        // cPrice = cDai / Dai price
        // aSupply = Total number of taDai in protocol
        // taPrice = taDai / Dai price
        // bSupply = Total number of tbDai in protocol (minimum 1 to avoid divide by 0?)
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
        /*if (trancheAddresses[_trancheNum].buyerCoinAddress == ETH_ADDR){
            _amount = msg.value;
            //Transfer ETH from msg.sender to protocol;
            TransferETHHelper.safeTransferETH(address(this), _amount);
            // transfer ETH to Aave receiving aEth
            //address _market, address _tokenAddr, uint256 _amount
            aaveDeposit(trancheAddresses[_trancheNum].lendingPoolAddressProvider, ETH_ADDR, _amount);
        } else {
            // check approve
            require(IERC20(trancheAddresses[_trancheNum].buyerCoinAddress).allowance(msg.sender, address(this)) >= _amount, "JCompound: allowance failed buying tranche A");
            //Transfer DAI from msg.sender to protocol;
            SafeERC20.safeTransferFrom(IERC20(trancheAddresses[_trancheNum].buyerCoinAddress), msg.sender, address(this), _amount);
            // transfer DAI to Coompound receiving cDai
            aaveDeposit(trancheAddresses[_trancheNum].lendingPoolAddressProvider, trancheAddresses[_trancheNum].buyerCoinAddress, _amount);
        }*/
        aaveDeposit(trancheAddresses[_trancheNum].lendingPoolAddressProvider, trancheAddresses[_trancheNum].buyerCoinAddress, _amount);
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
        require((block.number).sub(lastActivity[msg.sender]) >= redeemTimeout, "JCompound: redeem timeout not expired on tranche B");
        // check approve
        require(IERC20(trancheAddresses[_trancheNum].ATrancheAddress).allowance(msg.sender, address(this)) >= _amount, "JCompound: allowance failed redeeming tranche A");
        //Transfer DAI from msg.sender to protocol;
        SafeERC20.safeTransferFrom(IERC20(trancheAddresses[_trancheNum].ATrancheAddress), msg.sender, address(this), _amount);

        uint256 oldBal;
        uint256 diffBal;
        uint256 userAmount;
        uint256 feesAmount;
        setTrancheAExchangeRate(_trancheNum);
        uint256 taAmount = _amount.mul(trancheParameters[_trancheNum].storedTrancheAPrice).div(10 ** uint256(trancheParameters[_trancheNum].underlyingDecimals));
        if (trancheAddresses[_trancheNum].buyerCoinAddress == ETH_ADDR) {
            // calculate taETH amount via cETH price
            oldBal = getEthBalance();
            aaveWithdraw(trancheAddresses[_trancheNum].lendingPoolAddressProvider, ETH_ADDR, _amount);
            //newBal = getEthBalance();
            diffBal = getEthBalance().sub(oldBal);
            userAmount = diffBal.mul(trancheParameters[_trancheNum].redemptionPercentage).div(10000);
            TransferETHHelper.safeTransferETH(msg.sender, userAmount);
            if (diffBal != userAmount) {
                // transfer fees to JFeesCollector
                feesAmount = diffBal.sub(userAmount);
                TransferETHHelper.safeTransferETH(feesCollectorAddress, feesAmount);
            }   
        } else {
            // calculate taToken amount via cToken price
            oldBal = getTokenBalance(trancheAddresses[_trancheNum].buyerCoinAddress);
            aaveWithdraw(trancheAddresses[_trancheNum].lendingPoolAddressProvider, trancheAddresses[_trancheNum].buyerCoinAddress, _amount);
            diffBal = getTokenBalance(trancheAddresses[_trancheNum].buyerCoinAddress).sub(oldBal);
            userAmount = diffBal.mul(trancheParameters[_trancheNum].redemptionPercentage).div(10000);
            SafeERC20.safeTransfer(IERC20(trancheAddresses[_trancheNum].buyerCoinAddress), msg.sender, userAmount);
            if (diffBal != userAmount) {
                // transfer fees to JFeesCollector
                feesAmount = diffBal.sub(userAmount);
                SafeERC20.safeTransfer(IERC20(trancheAddresses[_trancheNum].buyerCoinAddress), feesCollectorAddress, feesAmount);
            }
        }
        
        IJTrancheTokens(trancheAddresses[_trancheNum].ATrancheAddress).burn(_amount);
        lastActivity[msg.sender] = block.number;
        trancheParameters[_trancheNum].trancheALastActionBlock = block.number;
        emit TrancheATokenBurned(_trancheNum, msg.sender, _amount, taAmount);
    }

    /**
     * @dev buy Tranche B Tokens
     * @param _trancheNum tranche number
     * @param _amount amount of stable coins sent by buyer
     */
    function buyTrancheBToken(uint256 _trancheNum, uint256 _amount) external payable locked {
        uint256 prevAaveTokenBalance = getTokenBalance(trancheAddresses[_trancheNum].aTokenAddress);
        // refresh value for tranche A
        setTrancheAExchangeRate(_trancheNum);
        // get tranche B exchange rate
        uint256 tbAmount = _amount.mul(10 ** uint256(trancheParameters[_trancheNum].underlyingDecimals)).div(getTrancheBExchangeRate(_trancheNum, _amount));
        /*if (trancheAddresses[_trancheNum].buyerCoinAddress == ETH_ADDR) {
            _amount = msg.value;
            TransferETHHelper.safeTransferETH(address(this), _amount);
            // transfer ETH to Coompound receiving cETH
            aaveDeposit(trancheAddresses[_trancheNum].lendingPoolAddressProvider, ETH_ADDR, _amount);
        } else {
            // check approve
            require(IERC20(trancheAddresses[_trancheNum].buyerCoinAddress).allowance(msg.sender, address(this)) >= _amount, "JCompound: allowance failed buying tranche B");
            //Transfer DAI from msg.sender to protocol;
            SafeERC20.safeTransferFrom(IERC20(trancheAddresses[_trancheNum].buyerCoinAddress), msg.sender, address(this), _amount);
            // transfer DAI to Couompound receiving cDai
            aaveDeposit(trancheAddresses[_trancheNum].lendingPoolAddressProvider, trancheAddresses[_trancheNum].buyerCoinAddress, _amount);
        }*/
        aaveDeposit(trancheAddresses[_trancheNum].lendingPoolAddressProvider, trancheAddresses[_trancheNum].buyerCoinAddress, _amount);
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
        require((block.number).sub(lastActivity[msg.sender]) >= redeemTimeout, "JCompound: redeem timeout not expired on tranche B");
        // check approve
        require(IERC20(trancheAddresses[_trancheNum].BTrancheAddress).allowance(msg.sender, address(this)) >= _amount, "JCompound: allowance failed redeeming tranche B");
        //Transfer DAI from msg.sender to protocol;
        SafeERC20.safeTransferFrom(IERC20(trancheAddresses[_trancheNum].BTrancheAddress), msg.sender, address(this), _amount);

        uint256 oldBal;
        uint256 diffBal;
        uint256 userAmount;
        uint256 feesAmount;
        // update tranche A price
        setTrancheAExchangeRate(_trancheNum);
        // get tranche B exchange rate
        uint256 tbAmount = _amount.mul(getTrancheBExchangeRate(_trancheNum, 0)).div(10 ** uint256(trancheParameters[_trancheNum].underlyingDecimals));
        if (trancheAddresses[_trancheNum].buyerCoinAddress == address(0)){
            // calculate tbETH amount via cETH price
            oldBal = getEthBalance();
            aaveWithdraw(trancheAddresses[_trancheNum].lendingPoolAddressProvider, ETH_ADDR, _amount);
            //withdrawEthFromAave(_trancheNum, _amount);
            diffBal = getEthBalance().sub(oldBal);
            userAmount = diffBal.mul(trancheParameters[_trancheNum].redemptionPercentage).div(10000);
            TransferETHHelper.safeTransferETH(msg.sender, userAmount);
            if (diffBal != userAmount) {
                // transfer fees to JFeesCollector
                feesAmount = diffBal.sub(userAmount);
                TransferETHHelper.safeTransferETH(feesCollectorAddress, feesAmount);
            }   
        } else {
            // calculate taToken amount via cToken price
            oldBal = getTokenBalance(trancheAddresses[_trancheNum].buyerCoinAddress);
            //withdrawErc20FromAave(_trancheNum, _amount);
            aaveWithdraw(trancheAddresses[_trancheNum].lendingPoolAddressProvider, trancheAddresses[_trancheNum].buyerCoinAddress, _amount);
            diffBal = getTokenBalance(trancheAddresses[_trancheNum].buyerCoinAddress);
            userAmount = diffBal.mul(trancheParameters[_trancheNum].redemptionPercentage).div(10000);
            SafeERC20.safeTransfer(IERC20(trancheAddresses[_trancheNum].buyerCoinAddress), msg.sender, userAmount);
            if (diffBal != userAmount) {
                // transfer fees to JFeesCollector
                feesAmount = diffBal.sub(userAmount);
                SafeERC20.safeTransfer(IERC20(trancheAddresses[_trancheNum].buyerCoinAddress), feesCollectorAddress, feesAmount);
            }   
        }
        
        IJTrancheTokens(trancheAddresses[_trancheNum].BTrancheAddress).burn(_amount);
        lastActivity[msg.sender] = block.number;
        emit TrancheBTokenBurned(_trancheNum, msg.sender, _amount, tbAmount);
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
     * @dev transfer tokens in this contract to owner address
     * @param _tokenContract token contract address
     * @param _amount token amount to be transferred 
     */
    function transferTokenToOwner(address _tokenContract, uint256 _amount) external onlyAdmins {
        SafeERC20.safeTransfer(IERC20(_tokenContract), feesCollectorAddress, _amount);
    }

    /**
     * @dev transfer ethers in this contract to owner address
     * @param _amount ethers amount to be transferred 
     */
    function withdrawEthToOwner(uint256 _amount) external onlyAdmins {
        TransferETHHelper.safeTransferETH(feesCollectorAddress, _amount);
    }

}