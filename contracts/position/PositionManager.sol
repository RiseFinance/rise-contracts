// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../order/OrderUtils.sol";
import "../market/Market.sol";
import "./PositionVault.sol";
import "./PnlManager.sol";

contract PositionManager is OrderUtils {
    PositionVault public positionVault;
    PnlManager public pnlManager;
    Market public market;

    // function iterateOpenPositions() public {}

    // iteration over the trader's open positions => (2 * listed market num) for each trader

    constructor(address _positionVault, address _pnlManager, address _market) {
        positionVault = PositionVault(_positionVault);
        pnlManager = PnlManager(_pnlManager);
        market = Market(_market);
    }

    function getTraderTotalUnrealizedPnl(
        address _trader,
        uint256[] calldata _markPrices // marketId as index
    ) public view returns (int256) {
        uint256 marketNum = market.getMarketIdCounter();

        bool _isLong = true;
        int256 totalUnrealizedPnl = 0;

        // iterate over the trader's open positions
        for (uint256 i = 0; i < marketNum; i++) {
            // iterate over long/short
            for (uint256 j = 0; j < 2; j++) {
                bytes32 key = _getPositionKey(_trader, _isLong, i);
                OpenPosition memory position = positionVault.getPosition(key);

                int256 _pnl = pnlManager._calculatePnL(
                    position.size,
                    position.avgOpenPrice,
                    _markPrices[i],
                    position.isLong
                );

                totalUnrealizedPnl += _pnl;
                _isLong = !_isLong;
            }
        }

        return totalUnrealizedPnl;
    }
}
