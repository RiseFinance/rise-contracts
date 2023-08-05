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
        OrderParams calldata p
    ) external returns (bytes32) {
        FillMarketOrderContext memory fmc;

        fmc.marginAssetId = market.getMarketInfo(p._marketId).marginAssetId;
        fmc.isBuy = p._isLong == p._isIncrease;

        fmc.avgExecPrice = _getAvgExecPriceAndUpdatePriceBuffer(
            p._marketId,
            p._sizeAbs,
            fmc.isBuy
        );

        fmc.key = _getPositionKey(msg.sender, p._isLong, p._marketId);

        // validations
        p._isIncrease
            ? orderValidator.validateIncreaseExecution(p)
            : orderValidator.validateDecreaseExecution(p, fmc.key);

        fmc.openPosition = positionVault.getPosition(fmc.key);

        // Execution type 1: open position
        if (fmc.openPosition.size == 0 && p._isIncrease) {
            fmc.execType = OrderExecType.OpenPosition;
            _executeIncreasePosition(fmc.execType, p, fmc);
        }

        // Execution type 2: increase position (update existing position)
        if (fmc.openPosition.size > 0 && p._isIncrease) {
            fmc.execType = OrderExecType.IncreasePosition;
            _executeIncreasePosition(fmc.execType, p, fmc);
        }

        // Execution type 3: decrease position
        if (
            fmc.openPosition.size > 0 &&
            !p._isIncrease &&
            p._sizeAbs != fmc.openPosition.size
        ) {
            fmc.execType = OrderExecType.DecreasePosition;
            _executeDecreasePosition(fmc.execType, p, fmc);
        }

        // Execution type 4: close position
        if (
            fmc.openPosition.size > 0 &&
            !p._isIncrease &&
            p._sizeAbs == fmc.openPosition.size
        ) {
            fmc.execType = OrderExecType.ClosePosition;
            _executeDecreasePosition(fmc.execType, p, fmc);
        }

        // create order record
        orderHistory.createOrderRecord(
            CreateOrderRecordParams(
                msg.sender,
                OrderType.Market,
                p._isLong,
                p._isIncrease,
                fmc.positionRecordId,
                p._marketId,
                p._sizeAbs,
                p._marginAbs,
                fmc.avgExecPrice
            )
        );

        // update global position state

        if (p._isLong) {
            globalState.updateGlobalLongPositionState(
                UpdateGlobalPositionStateParams(
                    p._isIncrease,
                    p._marketId,
                    p._sizeAbs,
                    p._marginAbs,
                    fmc.avgExecPrice
                )
            );
        } else {
            globalState.updateGlobalShortPositionState(
                UpdateGlobalPositionStateParams(
                    p._isIncrease,
                    p._marketId,
                    p._sizeAbs,
                    p._marginAbs,
                    fmc.avgExecPrice
                )
            );
        }

        return fmc.key;
    }

    function _executeIncreasePosition(
        OrderExecType _execType,
        OrderParams calldata p,
        FillMarketOrderContext memory fmc
    ) private {
        traderVault.decreaseTraderBalance(
            msg.sender,
            fmc.marginAssetId,
            p._marginAbs
        );

        p._isLong
            ? risePool.increaseLongReserveAmount(fmc.marginAssetId, p._sizeAbs)
            : risePool.increaseShortReserveAmount(
                fmc.marginAssetId,
                p._sizeAbs
            );

        if (_execType == OrderExecType.OpenPosition) {
            /// @dev for OpenPosition: PositionRecord => OpenPosition

            fmc.positionRecordId = positionHistory.openPositionRecord(
                OpenPositionRecordParams(
                    msg.sender,
                    p._marketId,
                    p._sizeAbs,
                    fmc.avgExecPrice,
                    0
                )
            );

            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    _execType,
                    fmc.key,
                    true, // isOpening
                    msg.sender,
                    p._isLong,
                    fmc.positionRecordId,
                    p._marketId,
                    fmc.avgExecPrice,
                    p._sizeAbs,
                    p._marginAbs,
                    p._isIncrease, // isIncreaseInSize
                    p._isIncrease // isIncreaseInMargin
                )
            );
        } else if (_execType == OrderExecType.IncreasePosition) {
            /// @dev for IncreasePosition: OpenPosition => PositionRecord

            fmc.positionRecordId = fmc.openPosition.currentPositionRecordId;

            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    _execType,
                    fmc.key,
                    false, // isOpening
                    msg.sender,
                    p._isLong,
                    fmc.positionRecordId,
                    p._marketId,
                    fmc.avgExecPrice,
                    p._sizeAbs,
                    p._marginAbs,
                    p._isIncrease, // isIncreaseInSize
                    p._isIncrease // isIncreaseInMargin
                )
            );

            positionHistory.updatePositionRecord(
                UpdatePositionRecordParams(
                    msg.sender,
                    fmc.key,
                    fmc.positionRecordId,
                    p._isIncrease,
                    fmc.pnl,
                    p._sizeAbs, // not used for increasing position
                    fmc.avgExecPrice // not used for increasing position
                )
            );
        } else {
            revert("Invalid execution type");
        }
    }

    function _executeDecreasePosition(
        OrderExecType _execType,
        OrderParams calldata p,
        FillMarketOrderContext memory fmc
    ) private {
        // PnL settlement
        fmc.pnl = settlePnL(
            fmc.openPosition,
            p._isLong,
            fmc.avgExecPrice,
            p._marketId,
            p._sizeAbs,
            p._marginAbs
        );

        fmc.positionRecordId = fmc.openPosition.currentPositionRecordId;

        if (_execType == OrderExecType.DecreasePosition) {
            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    _execType,
                    fmc.key,
                    false, // isOpening
                    msg.sender,
                    p._isLong,
                    fmc.positionRecordId,
                    p._marketId,
                    fmc.avgExecPrice,
                    p._sizeAbs,
                    p._marginAbs,
                    p._isIncrease, // isIncreaseInSize
                    p._isIncrease // isIncreaseInMargin
                )
            );

            positionHistory.updatePositionRecord(
                UpdatePositionRecordParams(
                    msg.sender,
                    fmc.key,
                    fmc.openPosition.currentPositionRecordId,
                    p._isIncrease,
                    fmc.pnl,
                    p._sizeAbs,
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
                    p._sizeAbs,
                    fmc.avgExecPrice
                )
            );
        } else {
            revert("Invalid execution type");
        }
    }
}
