// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../common/constants.sol";
import "../common/structs.sol";
import "../common/params.sol";

import "../account/TraderVault.sol";
import "../risepool/RisePool.sol";
import "../market/Market.sol";
import "../fee/Funding.sol";

contract PnlManager {
    using SafeCast for uint256;
    using SafeCast for int256;

    TraderVault public traderVault;
    RisePool public risePool;
    Funding public funding;
    Market public market;

    constructor(address _traderVault, address _risePool, address _market) {
        traderVault = TraderVault(_traderVault);
        risePool = RisePool(_risePool);
        market = Market(_market);
    }

    function settlePnL(
        OpenPosition memory _position,
        bool _isLong,
        uint256 _executionPrice,
        uint256 _marketId,
        uint256 _sizeAbs,
        uint256 _marginAbs
    ) public returns (int256) {
        MarketInfo memory marketInfo = market.getMarketInfo(_marketId);

        // uint256 sizeInUsd = _tokenToUsd(
        //     position.size,
        //     _executionPrice,
        //     tokenInfo.getTokenDecimals(market.getMarketInfo(_marketId).baseAssetId)
        // );

        int256 fundingFeeToPay = funding.getFundingFeeToPay(_position);
        int256 pnl = _calculatePnL(
            _sizeAbs,
            _position.avgOpenPrice,
            _executionPrice,
            _isLong
        );

        traderVault.increaseTraderBalance(
            _position.trader,
            marketInfo.marginAssetId,
            _marginAbs
        );

        // TODO: check - PnL includes margin?
        _isLong
            ? risePool.decreaseLongReserveAmount(_marketId, _sizeAbs)
            : risePool.decreaseShortReserveAmount(_marketId, _sizeAbs);

        // FIXME: TODO: funding fee 포함하여 Margin 잔고가 충분한지 검증하는 로직
        // FIXME: TODO: pnl을 token 수량으로 할지 USD로 할지 결정 (코드 미반영)

        int256 pnlAfterFundingFee = pnl - fundingFeeToPay;

        pnlAfterFundingFee >= 0
            ? traderVault.increaseTraderBalance(
                _position.trader,
                marketInfo.marginAssetId,
                (pnlAfterFundingFee).toUint256()
            )
            : traderVault.decreaseTraderBalance(
                _position.trader,
                marketInfo.marginAssetId,
                (-pnlAfterFundingFee).toUint256()
            );

        return pnlAfterFundingFee;
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
}
