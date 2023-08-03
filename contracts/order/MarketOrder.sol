// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../order/OrderUtils.sol";
import "../order/OrderPriceUtils.sol";
import "./OrderHistory.sol";
import "./OrderValidator.sol";
import "../position/PositionVault.sol";
import "../position/PositionHistory.sol";
import "../global/GlobalState.sol";
import "../common/params.sol";

contract MarketOrder is OrderUtils, OrderPriceUtils {
    OrderValidator orderValidator;
    OrderHistory orderHistory;
    PositionHistory positionHistory;
    GlobalState globalState;

    struct FillMarketOrderContext {
        OrderExecType execType;
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
    ) external returns (bytes32) {
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
            fmc.execType = OrderExecType.OpenPosition;

            _executeIncreasePosition(fmc.execType, c, fmc);
        }

        // Execution type 2: increase position (update existing position)
        if (fmc.openPosition.size > 0 && c._isIncrease) {
            fmc.execType = OrderExecType.IncreasePosition;

            _executeIncreasePosition(fmc.execType, c, fmc);
        }

        // Execution type 3: decrease position
        if (
            fmc.openPosition.size > 0 &&
            !c._isIncrease &&
            c._sizeAbs != fmc.openPosition.size
        ) {
            fmc.execType = OrderExecType.DecreasePosition;
            _executeDecreasePosition(fmc.execType, c, fmc);
        }

        // Execution type 4: close position
        if (
            fmc.openPosition.size > 0 &&
            !c._isIncrease &&
            c._sizeAbs == fmc.openPosition.size
        ) {
            fmc.execType = OrderExecType.ClosePosition;

            _executeDecreasePosition(fmc.execType, c, fmc);
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

    function _executeIncreasePosition(
        OrderExecType _execType,
        OrderContext calldata c,
        FillMarketOrderContext memory fmc
    ) private {
        traderVault.decreaseTraderBalance(
            msg.sender,
            fmc.marginAssetId,
            c._marginAbs
        );

        c._isLong
            ? risePool.increaseLongReserveAmount(fmc.marginAssetId, c._sizeAbs)
            : risePool.increaseShortReserveAmount(
                fmc.marginAssetId,
                c._sizeAbs
            );

        if (_execType == OrderExecType.OpenPosition) {
            /// @dev for OpenPosition: PositionRecord => OpenPosition

            fmc.positionRecordId = positionHistory.openPositionRecord(
                msg.sender,
                c._marketId,
                c._sizeAbs,
                fmc.avgExecPrice,
                0
            );

            UpdatePositionParams memory params = UpdatePositionParams(
                _execType,
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

            positionVault.updateOpenPosition(params);
        } else if (_execType == OrderExecType.IncreasePosition) {
            /// @dev for IncreasePosition: OpenPosition => PositionRecord

            fmc.positionRecordId = fmc.openPosition.currentPositionRecordId;

            UpdatePositionParams memory params = UpdatePositionParams(
                _execType,
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

            positionVault.updateOpenPosition(params);

            positionHistory.updatePositionRecord(
                msg.sender,
                fmc.key,
                fmc.positionRecordId,
                c._isIncrease
            );
        } else {
            revert("Invalid execution type");
        }
    }

    function _executeDecreasePosition(
        OrderExecType _execType,
        OrderContext calldata c,
        FillMarketOrderContext memory fmc
    ) private {
        // PnL settlement
        // (uint256 pnlUsdAbs, bool traderHasProfit) = settlePnL(
        settlePnL(
            fmc.key,
            c._isLong,
            fmc.avgExecPrice,
            c._marketId,
            c._sizeAbs,
            c._marginAbs
        );

        fmc.positionRecordId = fmc.openPosition.currentPositionRecordId;

        if (_execType == OrderExecType.DecreasePosition) {
            UpdatePositionParams memory params = UpdatePositionParams(
                _execType,
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

            positionVault.updateOpenPositionWithPnl(0, params); // FIXME: first arg is interimPnlUsd

            positionHistory.updatePositionRecord(
                msg.sender,
                fmc.key,
                fmc.openPosition.currentPositionRecordId,
                c._isIncrease
            );
        } else if (_execType == OrderExecType.ClosePosition) {
            positionVault.deleteOpenPosition(fmc.key);

            positionHistory.closePositionRecord(
                msg.sender,
                fmc.key,
                fmc.openPosition.currentPositionRecordId
            );
        } else {
            revert("Invalid execution type");
        }
    }
}
