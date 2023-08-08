// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../account/TraderVault.sol";

contract PositionFee {
    TraderVault public traderVault;

    uint256 public constant MARKET_POSITION_FEE_CONSTANT = 5;
    uint256 public constant LIMIT_POSITION_FEE_CONSTANT = 5;
    uint256 public constant POSITION_FEE_PRECISION = 1e4;
    uint256 public collectedPositionFees = 0;

    // TODO : POSITION_FEE_CONSTANT , POSITION_FEE_PRECISION 값 확인 필요

    constructor(address _traderVault) {
        traderVault = TraderVault(_traderVault);
    }

    function getLimitPositionFee(
        uint256 _sizeAbs
    ) public pure returns (uint256) {
        return
            (LIMIT_POSITION_FEE_CONSTANT * _sizeAbs) / POSITION_FEE_PRECISION;
    }

    function payLimitPositionFee(
        address _trader,
        uint256 _feeAssetId,
        uint256 _sizeAbs
    ) external {
        uint256 fee = getLimitPositionFee(_sizeAbs);
        traderVault.decreaseTraderBalance(_trader, _feeAssetId, fee);
        collectedPositionFees += fee;
    }

    function getMarketPositionFee(
        uint256 _sizeAbs
    ) public pure returns (uint256) {
        return
            (MARKET_POSITION_FEE_CONSTANT * _sizeAbs) / POSITION_FEE_PRECISION;
    }

    function payMarketPositionFee(
        address _trader,
        uint256 _feeAssetId,
        uint256 _sizeAbs
    ) external {
        uint256 fee = getMarketPositionFee(_sizeAbs);
        traderVault.decreaseTraderBalance(_trader, _feeAssetId, fee);
        collectedPositionFees += fee;
    }
}
