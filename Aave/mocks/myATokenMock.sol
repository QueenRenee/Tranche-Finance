// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {AToken} from '@aave/protocol-v2/contracts/protocol/tokenization/AToken.sol';
import {LendingPool} from '@aave/protocol-v2/contracts/protocol/lendingpool/LendingPool.sol';

contract myATokenMock is AToken {
  constructor(
    LendingPool pool,
    address underlyingAssetAddress,
    address reserveTreasury,
    string memory tokenName,
    string memory tokenSymbol,
    address incentivesController
  )
    public
    AToken(
      pool,
      underlyingAssetAddress,
      reserveTreasury,
      tokenName,
      tokenSymbol,
      incentivesController
    )
  {}

  function getRevision() internal pure override returns (uint256) {
    return 0x2;
  }

  function initialize(
    uint8 _underlyingAssetDecimals,
    string calldata _tokenName,
    string calldata _tokenSymbol
  ) external virtual override initializer {
    _setName(_tokenName);
    _setSymbol(_tokenSymbol);
    _setDecimals(_underlyingAssetDecimals);
  }
}
