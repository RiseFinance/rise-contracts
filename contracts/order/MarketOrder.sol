// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";

import "../position/PositionHistory.sol";
import "../position/PositionVault.sol";
import "../order/OrderExecutor.sol";
import "../order/PriceFetcher.sol";
import "../order/OrderUtils.sol";
import "../global/GlobalState.sol";
import "./OrderValidator.sol";
import "./OrderHistory.sol";

import "hardhat/console.sol";

contract MarketOrder is OrderExecutor {
    OrderValidator public orderValidator;
    OrderHistory public orderHistory;
    PriceFetcher public priceFetcher;
    GlobalState public globalState;

    constructor(
        address _traderVault,
        address _risePool,
        address _funding,
        address _market,
        address _positionHistory,
        address _positionVault,
        address _orderValidator,
        address _orderHistory,
        address _priceFetcher,
        address _globalState,
        address _positionFee
    )
        OrderExecutor(
            _traderVault,
            _risePool,
            _funding,
            _market,
            _positionHistory,
            _positionVault,
            _positionFee
        )
    {
        orderValidator = OrderValidator(_orderValidator);
        orderHistory = OrderHistory(_orderHistory);
        priceFetcher = PriceFetcher(_priceFetcher);
        globalState = GlobalState(_globalState);
    }

    function executeMarketOrder(
        OrderRequest calldata req
    ) external returns (bytes32) {
        // MarketOrderContext memory moc;
        ExecutionContext memory ec;

        ec.marketId = req.marketId;

        ec.sizeAbs = req.sizeAbs;
        ec.marginAbs = req.marginAbs;

        ec.marginAssetId = market.getMarketInfo(req.marketId).marginAssetId;
        // moc.isBuy = req.isLong == req.isIncrease;

        ec.avgExecPrice = priceFetcher._getAvgExecPrice(
            req.marketId,
            ec.sizeAbs,
            // moc.isBuy
            req.isLong == req.isIncrease // isBuy
        );

        ec.key = OrderUtils._getPositionKey(
            tx.origin,
            req.isLong,
            req.marketId
        );

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
                tx.origin,
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
