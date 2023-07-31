// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../risepool/RisePool.sol";
import "../account/TraderVault.sol";
import "../position/PositionVault.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";
import {USD_PRECISION} from "../common/constants.sol";

contract OrderUtils {
    PositionVault public positionVault;
    TraderVault public traderVault;
    TokenInfo public tokenInfo;
    RisePool public risePool;
    Market public market;

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

    function _getPositionKey(
        address _account,
        bool _isLong,
        uint256 _marketId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _isLong, _marketId));
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

    function _calculatePnL(
        uint256 _size,
        uint256 _averagePrice,
        uint256 _markPrice,
        bool _isLong
    ) public pure returns (uint256, bool) {
        uint256 pnlAbs = _markPrice >= _averagePrice
            ? (_size * (_markPrice - _averagePrice)) / USD_PRECISION
            : (_size * (_averagePrice - _markPrice)) / USD_PRECISION;
        bool hasProfit = _markPrice >= _averagePrice ? _isLong : !_isLong;
        return (pnlAbs, hasProfit);
    }

    function settlePnL(
        bytes32 _key,
        bool _isLong,
        uint256 _executionPrice,
        uint256 _marketId,
        uint256 _sizeAbs,
        uint256 _marginAbs
    ) external {
        Position memory position = positionVault.getPosition(_key);
        Market.MarketInfo memory marketInfo = market.getMarketInfo(_marketId);

        // uint256 sizeInUsd = _tokenToUsd(
        //     position.size,
        //     _executionPrice,
        //     tokenInfo.tokenDecimals(market.getMarketInfo(_marketId).baseAssetId)
        // );

        (uint256 pnlUsdAbs, bool traderHasProfit) = _calculatePnL(
            _sizeAbs,
            position.avgOpenPrice,
            _executionPrice,
            _isLong
        );

        traderVault.increaseTraderBalance(
            position.trader,
            marketInfo.marginAssetId,
            _marginAbs
        );

        if (traderHasProfit) {
            traderVault.increaseTraderBalance(
                position.trader,
                marketInfo.marginAssetId,
                pnlUsdAbs
            );
            _isLong
                ? risePool.decreaseLongPoolAmount(_marketId, pnlUsdAbs)
                : risePool.decreaseShortPoolAmount(_marketId, pnlUsdAbs);
        } else {
            traderVault.decreaseTraderBalance(
                position.trader,
                marketInfo.marginAssetId,
                pnlUsdAbs
            );
            _isLong
                ? risePool.increaseLongPoolAmount(_marketId, pnlUsdAbs)
                : risePool.increaseShortPoolAmount(_marketId, pnlUsdAbs);
        }

        // TODO: check - PnL includes margin?
        _isLong
            ? risePool.decreaseLongReserveAmount(_marketId, _sizeAbs)
            : risePool.decreaseShortReserveAmount(_marketId, _sizeAbs);
    }
}
