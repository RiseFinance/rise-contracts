// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../account/TraderVault.sol";
import "../market/Market.sol";
import {USD_PRECISION, PARTIAL_RATIO_PRECISION} from "../common/constants.sol";
using SafeCast for uint256;

contract OrderUtils {
    PositionVault public positionVault;
    TraderVault public traderVault;
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
    ) public pure returns (int256) {
        int256 pnl;
        _isLong
            ? pnl =
                (_size.toInt256() *
                    (_markPrice.toInt256() - _averagePrice.toInt256())) /
                USD_PRECISION.toInt256()
            : pnl =
            (_size.toInt256() *
                (_averagePrice.toInt256() - _markPrice.toInt256())) /
            USD_PRECISION.toInt256();
        return pnl;
    }

    function settlePnL(
        bytes32 _key,
        bool _isLong,
        uint256 _executionPrice,
        uint256 _marketId,
        uint256 _sizeAbs,
        uint256 _marginAbs
    ) public returns (int256) {
        OpenPosition memory position = positionVault.getPosition(_key);
        Market.MarketInfo memory marketInfo = market.getMarketInfo(_marketId);

        // uint256 sizeInUsd = _tokenToUsd(
        //     position.size,
        //     _executionPrice,
        //     tokenInfo.getTokenDecimals(market.getMarketInfo(_marketId).baseAssetId)
        // );

        int256 pnl = _calculatePnL(
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

        // TODO: check - PnL includes margin?
        _isLong
            ? risePool.decreaseLongReserveAmount(_marketId, _sizeAbs)
            : risePool.decreaseShortReserveAmount(_marketId, _sizeAbs);

        return pnl;
    }
}
