// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";

import "../position/PositionHistory.sol";
import "../position/PositionVault.sol";
import "../position/PnlManager.sol";
import "../order/PriceUtils.sol";
import "../order/OrderUtils.sol";
import "../global/GlobalState.sol";
import "./OrderHistory.sol";
import "./OrderValidator.sol";

contract MarketOrder is PnlManager, OrderUtils, PriceUtils {
    PositionHistory public positionHistory;
    PositionVault public positionVault;
    OrderValidator public orderValidator;
    OrderHistory public orderHistory;
    GlobalState public globalState;

    struct ExecutionContext {
        OpenPosition openPosition;
        OrderExecType execType;
        bytes32 key;
        uint256 marginAssetId;
        uint256 sizeAbs;
        uint256 marginAbs;
        uint256 positionRecordId;
        uint256 avgExecPrice;
        int256 pnl;
    }

    function executeMarketOrder(
        OrderRequest calldata req
    ) external returns (bytes32) {
        // MarketOrderContext memory moc;
        ExecutionContext memory ec;

        ec.marginAssetId = market.getMarketInfo(req.marketId).marginAssetId;
        // moc.isBuy = req.isLong == req.isIncrease;

        ec.avgExecPrice = _getAvgExecPriceAndUpdatePriceBuffer(
            req.marketId,
            req.sizeAbs,
            // moc.isBuy
            req.isLong == req.isIncrease // isBuy
        );

        ec.key = _getPositionKey(msg.sender, req.isLong, req.marketId);

        // validations
        req.isIncrease
            ? orderValidator.validateIncreaseExecution(req)
            : orderValidator.validateDecreaseExecution(req, ec.key);

        ec.openPosition = positionVault.getPosition(ec.key);

        // Execution type 1: open position
        if (ec.openPosition.size == 0 && req.isIncrease) {
            ec.execType = OrderExecType.OpenPosition;

            _executeIncreasePosition(req, ec);
        }

        // Execution type 2: increase position (update existing position)
        if (ec.openPosition.size > 0 && req.isIncrease) {
            ec.execType = OrderExecType.IncreasePosition;

            _executeIncreasePosition(req, ec);
        }

        // Execution type 3: decrease position
        if (
            ec.openPosition.size > 0 &&
            !req.isIncrease &&
            req.sizeAbs != ec.openPosition.size
        ) {
            ec.execType = OrderExecType.DecreasePosition;

            _executeDecreasePosition(req, ec);
        }

        // Execution type 4: close position
        if (
            ec.openPosition.size > 0 &&
            !req.isIncrease &&
            req.sizeAbs == ec.openPosition.size
        ) {
            ec.execType = OrderExecType.ClosePosition;

            _executeDecreasePosition(req, ec);
        }

        // create order record
        orderHistory.createOrderRecord(
            CreateOrderRecordParams(
                msg.sender,
                OrderType.Market,
                req.isLong,
                req.isIncrease,
                ec.positionRecordId,
                req.marketId,
                req.sizeAbs,
                req.marginAbs,
                ec.avgExecPrice
            )
        );

        // update global position state

        if (req.isLong) {
            globalState.updateGlobalLongPositionState(
                UpdateGlobalPositionStateParams(
                    req.isIncrease,
                    req.marketId,
                    req.sizeAbs,
                    req.marginAbs,
                    ec.avgExecPrice
                )
            );
        } else {
            globalState.updateGlobalShortPositionState(
                UpdateGlobalPositionStateParams(
                    req.isIncrease,
                    req.marketId,
                    req.sizeAbs,
                    req.marginAbs,
                    ec.avgExecPrice
                )
            );
        }

        return ec.key;
    }

    function _executeIncreasePosition(
        OrderRequest calldata req,
        ExecutionContext memory ec
    ) private {
        traderVault.decreaseTraderBalance(
            msg.sender,
            ec.marginAssetId,
            req.marginAbs
        );

        req.isLong
            ? risePool.increaseLongReserveAmount(ec.marginAssetId, req.sizeAbs)
            : risePool.increaseShortReserveAmount(
                ec.marginAssetId,
                req.sizeAbs
            );

        if (ec.execType == OrderExecType.OpenPosition) {
            /// @dev for OpenPosition: PositionRecord => OpenPosition

            ec.positionRecordId = positionHistory.openPositionRecord(
                OpenPositionRecordParams(
                    msg.sender,
                    req.marketId,
                    req.sizeAbs,
                    ec.avgExecPrice,
                    0
                )
            );

            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    ec.execType,
                    ec.key,
                    true, // isOpening
                    msg.sender,
                    req.isLong,
                    ec.positionRecordId,
                    req.marketId,
                    ec.avgExecPrice,
                    req.sizeAbs,
                    req.marginAbs,
                    req.isIncrease, // isIncreaseInSize
                    req.isIncrease // isIncreaseInMargin
                )
            );
        } else if (ec.execType == OrderExecType.IncreasePosition) {
            /// @dev for IncreasePosition: OpenPosition => PositionRecord

            ec.positionRecordId = ec.openPosition.currentPositionRecordId;

            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    ec.execType,
                    ec.key,
                    false, // isOpening
                    msg.sender,
                    req.isLong,
                    ec.positionRecordId,
                    req.marketId,
                    ec.avgExecPrice,
                    req.sizeAbs,
                    req.marginAbs,
                    req.isIncrease, // isIncreaseInSize
                    req.isIncrease // isIncreaseInMargin
                )
            );

            positionHistory.updatePositionRecord(
                UpdatePositionRecordParams(
                    msg.sender,
                    ec.key,
                    ec.positionRecordId,
                    req.isIncrease,
                    ec.pnl,
                    req.sizeAbs, // not used for increasing position
                    ec.avgExecPrice // not used for increasing position
                )
            );
        } else {
            revert("Invalid execution type");
        }
    }

    function _executeDecreasePosition(
        OrderRequest calldata req,
        ExecutionContext memory ec
    ) private {
        // PnL settlement
        ec.pnl = settlePnL(
            ec.openPosition,
            req.isLong,
            ec.avgExecPrice,
            req.marketId,
            req.sizeAbs,
            req.marginAbs
        );

        ec.positionRecordId = ec.openPosition.currentPositionRecordId;

        if (ec.execType == OrderExecType.DecreasePosition) {
            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    ec.execType,
                    ec.key,
                    false, // isOpening
                    msg.sender,
                    req.isLong,
                    ec.positionRecordId,
                    req.marketId,
                    ec.avgExecPrice,
                    req.sizeAbs,
                    req.marginAbs,
                    req.isIncrease, // isIncreaseInSize
                    req.isIncrease // isIncreaseInMargin
                )
            );

            positionHistory.updatePositionRecord(
                UpdatePositionRecordParams(
                    msg.sender,
                    ec.key,
                    ec.openPosition.currentPositionRecordId,
                    req.isIncrease,
                    ec.pnl,
                    req.sizeAbs,
                    ec.avgExecPrice
                )
            );
        } else if (ec.execType == OrderExecType.ClosePosition) {
            positionVault.deleteOpenPosition(ec.key);

            positionHistory.closePositionRecord(
                ClosePositionRecordParams(
                    msg.sender,
                    ec.openPosition.currentPositionRecordId,
                    ec.pnl,
                    req.sizeAbs,
                    ec.avgExecPrice
                )
            );
        } else {
            revert("Invalid execution type");
        }
    }
}
