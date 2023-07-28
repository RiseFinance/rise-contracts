// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/Context.sol";
import "../risepool/RisePool.sol";
import "../account/TraderVault.sol";
import "../position/PositionVault.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";

contract OrderUtils is Context {
    RisePool public risePool;
    TraderVault public traderVault;
    PositionVault public positionVault;
    TokenInfo public tokenInfo;
    Market public market;

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
