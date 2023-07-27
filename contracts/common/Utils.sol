// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "hardhat/console.sol"; // test-only
import "./Constants.sol";

abstract contract Utils is Constants {
    function _min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function _abs(int256 x) public pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    function _getPositionKey(
        address _account,
        bool _isLong,
        uint256 _indexAssetId,
        uint256 _collateralAssetId
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _account,
                    _isLong,
                    _indexAssetId,
                    _collateralAssetId
                )
            );
    }

    /**
     * (new avg price) * (new size) = (old avg price) * (old size) + (mark price) * (size delta)
     * */
    function _getNextAvgPrice(
        bool _isIncreaseInSize,
        uint256 _prevSizeInUsd,
        uint256 _prevAvgPrice,
        uint256 _sizeDeltaInUsd,
        uint256 _markPrice
    ) public pure returns (uint256) {
        uint256 _prevSizeInTokens = _prevAvgPrice == 0
            ? 0
            : (_prevSizeInUsd / _prevAvgPrice);

        uint256 _sizeDeltaInTokens = (_sizeDeltaInUsd / _markPrice);

        if (_isIncreaseInSize) {
            uint256 newSize = _prevSizeInTokens + _sizeDeltaInTokens;
            uint256 nextAvgPrice = newSize == 0
                ? 0
                : (_prevAvgPrice *
                    _prevSizeInTokens +
                    _markPrice *
                    _sizeDeltaInTokens) / newSize;
            return nextAvgPrice;
        } else {
            // TODO: check - this logic needed?
            uint256 newSize = _prevSizeInTokens - _sizeDeltaInTokens;
            uint256 nextAvgPrice = newSize == 0
                ? 0
                : (_prevAvgPrice *
                    _prevSizeInTokens -
                    _markPrice *
                    _sizeDeltaInTokens) / newSize;
            return nextAvgPrice;
        }
    }

    function _getAvgExecutionPrice(
        uint256 _basePrice,
        uint256 _priceImpactInUsd,
        bool _isIncrease
    ) internal pure returns (uint256) {
        return
            _isIncrease
                ? _basePrice + (_priceImpactInUsd / 2)
                : _basePrice - (_priceImpactInUsd / 2);
    }

    function _usdToToken(
        uint256 _usdAmount,
        uint256 _tokenPrice,
        uint256 _tokenDecimals
    ) public pure returns (uint256) {
        return
            ((_usdAmount * 10 ** _tokenDecimals) / USD_PRECISION) / _tokenPrice;
    }

    function _tokenToUsd(
        uint256 _tokenAmount,
        uint256 _tokenPrice,
        uint256 _tokenDecimals
    ) public pure returns (uint256) {
        return
            ((_tokenAmount * _tokenPrice) * USD_PRECISION) /
            10 ** _tokenDecimals;
    }

    function _calculatePnL(
        uint256 _sizeInUsd,
        uint256 _averagePrice,
        uint256 _markPrice,
        bool _isLong
    ) public pure returns (uint256, bool) {
        uint256 pnlAbs = _markPrice >= _averagePrice
            ? (_sizeInUsd * (_markPrice - _averagePrice)) / USD_PRECISION
            : (_sizeInUsd * (_averagePrice - _markPrice)) / USD_PRECISION;
        bool hasProfit = _markPrice >= _averagePrice ? _isLong : !_isLong;
        return (pnlAbs, hasProfit);
    }
}
