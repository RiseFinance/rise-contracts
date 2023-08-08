// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";

import "../position/PositionHistory.sol";
import "../position/PositionVault.sol";
import "../order/OrderExecutor.sol";
import "../order/PriceUtils.sol";
import "../order/OrderUtils.sol";
import "../global/GlobalState.sol";
import "./OrderHistory.sol";
import "./OrderValidator.sol";

contract MarketOrder is OrderExecutor, OrderUtils, PriceUtils {
    OrderValidator public orderValidator;
    OrderHistory public orderHistory;
    GlobalState public globalState;

    function executeMarketOrder(
        OrderRequest calldata req
    ) external returns (bytes32) {
        // MarketOrderContext memory moc;
        ExecutionContext memory ec;

        ec.sizeAbs = ec.sizeAbs;
        ec.marginAbs = ec.marginAbs;

        ec.marginAssetId = market.getMarketInfo(req.marketId).marginAssetId;
        // moc.isBuy = req.isLong == req.isIncrease;

        ec.avgExecPrice = _getAvgExecPrice(
            req.marketId,
            ec.sizeAbs,
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
            ec.sizeAbs != ec.openPosition.size
        ) {
            ec.execType = OrderExecType.DecreasePosition;

            _executeDecreasePosition(req, ec);
        }

        // Execution type 4: close position
        if (
            ec.openPosition.size > 0 &&
            !req.isIncrease &&
            ec.sizeAbs == ec.openPosition.size
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
                ec.sizeAbs,
                ec.marginAbs,
                ec.avgExecPrice
            )
        );

        // update global position state

        if (req.isLong) {
            globalState.updateGlobalLongPositionState(
                UpdateGlobalPositionStateParams(
                    req.isIncrease,
                    req.marketId,
                    ec.sizeAbs,
                    ec.marginAbs,
                    ec.avgExecPrice
                )
            );
        } else {
            globalState.updateGlobalShortPositionState(
                UpdateGlobalPositionStateParams(
                    req.isIncrease,
                    req.marketId,
                    ec.sizeAbs,
                    ec.marginAbs,
                    ec.avgExecPrice
                )
            );
        }

        return ec.key;
    }
}
