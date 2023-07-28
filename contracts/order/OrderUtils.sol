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
        // Position memory position = positions[_key];
        Position memory position = positionVault.getPosition(_key);

        uint256 sizeInUsd = _tokenToUsd(
            position.size,
            _executionPrice,
            tokenInfo.tokenDecimals(market.getMarketInfo(_marketId).baseAssetId)
        );

        (uint256 pnlUsdAbs, bool traderHasProfit) = _calculatePnL(
            sizeInUsd,
            position.avgOpenPrice,
            _executionPrice,
            _isLong
        );
        // FIXME: TODO: Impl.
        // traderVault.increaseTraderBalance(
        //     msg.sender,
        //     _marginAssetId,
        //     _marginAbsInUsd
        // ); // TODO: check - is it `msg.sender`?

        // if (traderHasProfit) {
        //     traderVault.increaseTraderBalance(
        //         msg.sender,
        //         _marginAssetId,
        //         pnlUsdAbs
        //     );
        //     risePool.decreasePoolAmounts(USD_ID, pnlUsdAbs); // TODO: check - USD or token?
        // } else {
        //     traderVault.decreaseTraderBalance(
        //         msg.sender,
        //         _marginAssetId,
        //         pnlUsdAbs
        //     );
        //     risePool.increasePoolAmounts(USD_ID, pnlUsdAbs);
        // }
        // // TODO: check - PnL includes margin?

        // risePool.decreaseReserveAmounts(_indexAssetId, _sizeAbsInUsd);
    }
}
