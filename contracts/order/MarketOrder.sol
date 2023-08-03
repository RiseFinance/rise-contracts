// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../order/OrderUtils.sol";
import "./OrderHistory.sol";
import "./OrderValidator.sol";
import "../position/PositionVault.sol";
import "../position/PositionHistory.sol";
import "../global/GlobalState.sol";

contract MarketOrder is OrderUtils {
    OrderValidator orderValidator;
    OrderHistory orderHistory;
    PositionHistory positionHistory;
    GlobalState globalState;

    struct FillMarketOrderContext {
        bool isBuy;
        bool isOpen;
        uint256 marginAssetId;
        uint256 avgExecPrice;
        bytes32 key;
        OpenPosition openPosition;
        uint256 positionRecordId;
    }

    function executeMarketOrder(
        OrderContext calldata c
    ) private returns (bytes32) {
        FillMarketOrderContext memory fmc;

        fmc.marginAssetId = market.getMarketInfo(c._marketId).marginAssetId;
        fmc.isBuy = c._isLong == c._isIncrease;

        fmc.avgExecPrice = _getAvgExecPriceAndUpdatePriceBuffer(
            c._marketId,
            c._sizeAbs,
            fmc.isBuy
        );

        fmc.key = _getPositionKey(msg.sender, c._isLong, c._marketId);

        // validations
        c._isIncrease
            ? orderValidator.validateIncreaseExecution(c)
            : orderValidator.validateDecreaseExecution(c, fmc.key);

        fmc.openPosition = positionVault.getPosition(fmc.key);

        // Execution type 1: open position
        if (fmc.openPosition.size == 0 && c._isIncrease) {
            traderVault.decreaseTraderBalance(
                msg.sender,
                fmc.marginAssetId,
                c._marginAbs
            );
            c._isLong
                ? risePool.increaseLongReserveAmount(
                    fmc.marginAssetId,
                    c._sizeAbs
                )
                : risePool.increaseShortReserveAmount(
                    fmc.marginAssetId,
                    c._sizeAbs
                );

            // create position record
            fmc.positionRecordId = positionHistory.openPositionRecord(
                msg.sender,
                c._marketId,
                c._sizeAbs,
                fmc.avgExecPrice,
                0
            );

            positionVault.updateOpenPosition(
                fmc.key,
                true, // isOpening
                msg.sender,
                c._isLong,
                fmc.positionRecordId,
                c._marketId,
                fmc.avgExecPrice,
                c._sizeAbs,
                c._marginAbs,
                c._isIncrease, // isIncreaseInSize
                c._isIncrease // isIncreaseInMargin
            );
        }

        // Execution type 2: increase position (update existing position)
        if (fmc.openPosition.size > 0 && c._isIncrease) {
            traderVault.decreaseTraderBalance(
                msg.sender,
                fmc.marginAssetId,
                c._marginAbs
            );
            c._isLong
                ? risePool.increaseLongReserveAmount(
                    fmc.marginAssetId,
                    c._sizeAbs
                )
                : risePool.increaseShortReserveAmount(
                    fmc.marginAssetId,
                    c._sizeAbs
                );

            positionVault.updateOpenPosition(
                fmc.key,
                false, // isOpening
                msg.sender,
                c._isLong,
                fmc.positionRecordId,
                c._marketId,
                fmc.avgExecPrice,
                c._sizeAbs,
                c._marginAbs,
                c._isIncrease, // isIncreaseInSize
                c._isIncrease // isIncreaseInMargin
            );

            // update position record
            positionHistory.updatePositionRecord(
                msg.sender,
                fmc.key,
                fmc.openPosition.currentPositionRecordId,
                c._isIncrease
            );
        }

        // Execution type 3: decrease position
        if (fmc.openPosition.size > 0 && !c._isIncrease) {
            // PnL settlement
            settlePnL(
                fmc.key,
                c._isLong,
                fmc.avgExecPrice,
                c._marketId,
                c._sizeAbs,
                c._marginAbs
            );

            positionVault.updateOpenPosition(
                fmc.key,
                false, // isOpening
                msg.sender,
                c._isLong,
                fmc.positionRecordId,
                c._marketId,
                fmc.avgExecPrice,
                c._sizeAbs,
                c._marginAbs,
                c._isIncrease, // isIncreaseInSize
                c._isIncrease // isIncreaseInMargin
            );

            // update position record
            positionHistory.updatePositionRecord(
                msg.sender,
                fmc.key,
                fmc.openPosition.currentPositionRecordId,
                c._isIncrease
            );
        }

        // Execution type 4: close position
        if (
            fmc.openPosition.size > 0 &&
            !c._isIncrease &&
            c._sizeAbs == fmc.openPosition.size
        ) {
            // PnL settlement
            settlePnL(
                fmc.key,
                c._isLong,
                fmc.avgExecPrice,
                c._marketId,
                c._sizeAbs,
                c._marginAbs
            );

            positionVault.deleteOpenPosition(fmc.key);

            // update position record
            positionHistory.closePositionRecord(
                msg.sender,
                fmc.key,
                fmc.openPosition.currentPositionRecordId
            );
        }

        // fill the order
        orderHistory.createOrderRecord(
            msg.sender,
            OrderType.Market,
            c._isLong,
            c._isIncrease,
            fmc.positionRecordId,
            c._marketId,
            c._sizeAbs,
            c._marginAbs,
            fmc.avgExecPrice
        );

        // update global position state

        if (c._isLong) {
            globalState.updateGlobalLongPositionState(
                c._isIncrease,
                c._marketId,
                c._sizeAbs,
                c._marginAbs,
                fmc.avgExecPrice
            );
        } else {
            globalState.updateGlobalShortPositionState(
                c._isIncrease,
                c._marketId,
                c._sizeAbs,
                c._marginAbs,
                fmc.avgExecPrice
            );
        }

        return fmc.key;
    }
}
