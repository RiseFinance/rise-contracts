// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/params.sol";

import "../position/PositionHistory.sol";
import "../position/PositionVault.sol";
import "../position/PnlManager.sol";
import "../order/OrderPriceUtils.sol";
import "../order/OrderUtils.sol";
import "../global/GlobalState.sol";
import "./OrderHistory.sol";
import "./OrderValidator.sol";

contract MarketOrder is PnlManager, OrderUtils, OrderPriceUtils {
    PositionHistory public positionHistory;
    PositionVault public positionVault;
    OrderValidator public orderValidator;
    OrderHistory public orderHistory;
    GlobalState public globalState;

    struct FillMarketOrderContext {
        OpenPosition openPosition;
        OrderExecType execType;
        bytes32 key;
        bool isBuy;
        bool isOpen;
        int256 pnl;
        uint256 positionRecordId;
        uint256 marginAssetId;
        uint256 avgExecPrice;
    }

    function executeMarketOrder(
        OrderParams calldata c
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

        // create order record
        orderHistory.createOrderRecord(
            CreateOrderRecordParams(
                msg.sender,
                OrderType.Market,
                c._isLong,
                c._isIncrease,
                fmc.positionRecordId,
                c._marketId,
                c._sizeAbs,
                c._marginAbs,
                fmc.avgExecPrice
            )
        );

        // update global position state

        if (c._isLong) {
            globalState.updateGlobalLongPositionState(
                UpdateGlobalPositionStateParams(
                    c._isIncrease,
                    c._marketId,
                    c._sizeAbs,
                    c._marginAbs,
                    fmc.avgExecPrice
                )
            );
        } else {
            globalState.updateGlobalShortPositionState(
                UpdateGlobalPositionStateParams(
                    c._isIncrease,
                    c._marketId,
                    c._sizeAbs,
                    c._marginAbs,
                    fmc.avgExecPrice
                )
            );
        }

        return fmc.key;
    }

    function _executeIncreasePosition(
        OrderExecType _execType,
        OrderParams calldata c,
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
                OpenPositionRecordParams(
                    msg.sender,
                    c._marketId,
                    c._sizeAbs,
                    fmc.avgExecPrice,
                    0
                )
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
                UpdatePositionRecordParams(
                    msg.sender,
                    fmc.key,
                    fmc.positionRecordId,
                    c._isIncrease,
                    fmc.pnl,
                    c._sizeAbs, // not used for increasing position
                    fmc.avgExecPrice // not used for increasing position
                )
            );
        } else {
            revert("Invalid execution type");
        }
    }

    function _executeDecreasePosition(
        OrderExecType _execType,
        OrderParams calldata c,
        FillMarketOrderContext memory fmc
    ) private {
        // PnL settlement
        fmc.pnl = settlePnL(
            fmc.openPosition,
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

            // positionVault.updateOpenPositionWithPnl(0, params); // FIXME: first arg is interimPnlUsd
            positionVault.updateOpenPosition(params);

            positionHistory.updatePositionRecord(
                UpdatePositionRecordParams(
                    msg.sender,
                    fmc.key,
                    fmc.openPosition.currentPositionRecordId,
                    c._isIncrease,
                    fmc.pnl,
                    c._sizeAbs,
                    fmc.avgExecPrice
                )
            );
        } else if (_execType == OrderExecType.ClosePosition) {
            positionVault.deleteOpenPosition(fmc.key);

            positionHistory.closePositionRecord(
                ClosePositionRecordParams(
                    msg.sender,
                    fmc.openPosition.currentPositionRecordId,
                    fmc.pnl,
                    c._sizeAbs,
                    fmc.avgExecPrice
                )
            );
        } else {
            revert("Invalid execution type");
        }
    }
}
