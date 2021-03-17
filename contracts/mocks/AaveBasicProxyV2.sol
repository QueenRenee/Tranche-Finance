// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/ILendingPool.sol";
import "./DSMath.sol";
import "../TokenInterface.sol";


contract AaveBasicProxyV2 is DSMath {

    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // mainnet

	address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint16 public constant AAVE_REFERRAL_CODE = 0;

    receive() external virtual payable {}

    function getDataProvider(address _market) internal view returns(ILendingPoolAddressesProvider) {
        return ILendingPoolAddressesProvider(ILendingPoolAddressesProvider(_market).getAddress(0x0100000000000000000000000000000000000000000000000000000000000000));
    }

    /// @notice Approves token contract to pull underlying tokens
    /// @param _tokenAddr Token we are trying to approve
    /// @param _caller Address which will gain the approval
    function approveToken(address _tokenAddr, address _caller) internal {
        if (_tokenAddr != ETH_ADDR) {
            SafeERC20.safeApprove(IERC20(_tokenAddr), _caller, uint256(-1));
        }
    }

    /// @notice User deposits tokens to the Aave protocol
    /// @param _market address provider for specific market
    /// @param _tokenAddr The address of the token to be deposited
    /// @param _amount Amount of tokens to be deposited
    function deposit(address _market, address _tokenAddr, uint256 _amount) public payable {
        address lendingPool = ILendingPoolAddressesProvider(_market).getLendingPool();

        if (_tokenAddr == ETH_ADDR) {
            require(msg.value == _amount);
            TokenInterface(WETH_ADDRESS).deposit{value: _amount}();
            _tokenAddr = WETH_ADDRESS;
        } else {
            SafeERC20.safeTransferFrom(IERC20(_tokenAddr), msg.sender, address(this), _amount);
        }

        approveToken(_tokenAddr, lendingPool);
        ILendingPool(lendingPool).deposit(_tokenAddr, _amount, address(this), AAVE_REFERRAL_CODE);
    }

    /// @notice User withdraws tokens from the Aave protocol
    /// @param _market address provider for specific market
    /// @param _tokenAddr The address of the token to be withdrawn
    /// @param _amount Amount of tokens to be withdrawn -> send -1 for whole amount
    function withdraw(address _market, address _tokenAddr, uint256 _amount) public {
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

    /// @notice User borrows tokens to the Aave protocol
    /// @param _market address provider for specific market
    /// @param _tokenAddr The address of the token to be borrowed
    /// @param _amount Amount of tokens to be borrowed
    /// @param _type Send 1 for stable rate and 2 for variable
    function borrow(address _market, address _tokenAddr, uint256 _amount, uint256 _type) public {
        address lendingPool = ILendingPoolAddressesProvider(_market).getLendingPool();
        _tokenAddr = changeToWeth(_tokenAddr);

        ILendingPool(lendingPool).borrow(_tokenAddr, _amount, _type, AAVE_REFERRAL_CODE, address(this));

        if (_tokenAddr == WETH_ADDRESS) {
            // we do this so the user gets eth instead of weth
            TokenInterface(WETH_ADDRESS).withdraw(_amount);
            _tokenAddr = ETH_ADDR;
        }

        withdrawTokens(_tokenAddr);
    }

    /// @dev User paybacks tokens to the Aave protocol
    /// @param _market address provider for specific market
    /// @param _tokenAddr The address of the token to be paybacked
    /// @param _amount Amount of tokens to be payed back
    function payback(address _market, address _tokenAddr, uint256 _amount, uint256 _rateMode) public payable {
        address lendingPool = ILendingPoolAddressesProvider(_market).getLendingPool();
        _tokenAddr = changeToWeth(_tokenAddr);

        if (_tokenAddr == WETH_ADDRESS) {
            TokenInterface(WETH_ADDRESS).deposit{value: msg.value}();
        } else {
            uint amountToPull = min(_amount, IERC20(_tokenAddr).balanceOf(msg.sender));
            SafeERC20.safeTransferFrom(IERC20(_tokenAddr), msg.sender, address(this), amountToPull);
        }

        approveToken(_tokenAddr, lendingPool);
        ILendingPool(lendingPool).repay(_tokenAddr, _amount, _rateMode, payable(address(this)));

        if (_tokenAddr == WETH_ADDRESS) {
            // Pull if we have any eth leftover
            TokenInterface(WETH_ADDRESS).withdraw(IERC20(WETH_ADDRESS).balanceOf(address(this)));
            _tokenAddr = ETH_ADDR;
        }

        withdrawTokens(_tokenAddr);
    }

    /// @dev User paybacks tokens to the Aave protocol
    /// @param _market address provider for specific market
    /// @param _tokenAddr The address of the token to be paybacked
    /// @param _amount Amount of tokens to be payed back
    function paybackOnBehalf(address _market, address _tokenAddr, uint256 _amount, uint256 _rateMode, address _onBehalf) public payable {
        address lendingPool = ILendingPoolAddressesProvider(_market).getLendingPool();
        _tokenAddr = changeToWeth(_tokenAddr);

        if (_tokenAddr == WETH_ADDRESS) {
            TokenInterface(WETH_ADDRESS).deposit{value: msg.value}();
        } else {
            uint amountToPull = min(_amount, IERC20(_tokenAddr).allowance(msg.sender, address(this)));
            SafeERC20.safeTransferFrom(IERC20(_tokenAddr), msg.sender, address(this), amountToPull);
        }

        approveToken(_tokenAddr, lendingPool);
        ILendingPool(lendingPool).repay(_tokenAddr, _amount, _rateMode, _onBehalf);

        if (_tokenAddr == WETH_ADDRESS) {
            // we do this so the user gets eth instead of weth
            TokenInterface(WETH_ADDRESS).withdraw(_amount);
            _tokenAddr = ETH_ADDR;
        }

        withdrawTokens(_tokenAddr);
    }


    /// @notice Helper method to withdraw tokens
    /// @param _tokenAddr Address of the token to be withdrawn
    function withdrawTokens(address _tokenAddr) public {
        uint256 amount = _tokenAddr == ETH_ADDR ? address(this).balance : IERC20(_tokenAddr).balanceOf(address(this));

        if (amount > 0) {
            if (_tokenAddr != ETH_ADDR) {
                SafeERC20.safeTransfer(IERC20(_tokenAddr), msg.sender, amount);
            } else {
                msg.sender.transfer(amount);
            }
        }
    }

    function setUserUseReserveAsCollateral(address _market, address _tokenAddr, bool _true) public {
        address lendingPool = ILendingPoolAddressesProvider(_market).getLendingPool();

        ILendingPool(lendingPool).setUserUseReserveAsCollateral(_tokenAddr, _true);
    }

    // stable = 1, variable = 2
    function swapBorrowRateMode(address _market, address _reserve, uint _rateMode) public {
        address lendingPool = ILendingPoolAddressesProvider(_market).getLendingPool();

        ILendingPool(lendingPool).swapBorrowRateMode(_reserve, _rateMode);
    }

    function changeToWeth(address _token) private pure returns(address) {
        if (_token == ETH_ADDR) {
            return WETH_ADDRESS;
        }

        return _token;
    }

}
