// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../common/Modifiers.sol";
import "../common/MathUtils.sol";
import "../common/constants.sol";
import "../common/params.sol";

import "../position/PositionHistory.sol";
import "../position/PositionVault.sol";
import "../position/PnlManager.sol";
import "../global/GlobalState.sol";
import "../order/OrderHistory.sol";
import "../order/OrderUtils.sol";
import "../market/TokenInfo.sol";
import "./OrderBookBase.sol";

import "hardhat/console.sol";

contract OrderBook is
    OrderBookBase,
    PnlManager,
    OrderUtils,
    Modifiers,
    MathUtils
{
    using SafeCast for int256;
    using SafeCast for uint256;

    PositionHistory public positionHistory;
    PositionVault public positionVault;
    OrderHistory public orderHistory;
    GlobalState public globalState;
    TokenInfo public tokenInfo;

    struct IterationContext {
        bool loopCondition;
        uint256 interimMarkPrice;
        uint256 limitPriceIterator;
    }

    struct PriceTickIterationContext {
        bool isPartialForThePriceTick;
        uint256 sizeCap;
        uint256 sizeCapInUsd;
        uint256 fillAmount;
        uint256 priceImpactInUsd;
        uint256 avgExecutionPrice;
        uint256 firstIdx;
        uint256 lastIdx;
    }

    struct FillLimitOrderContext {
        OpenPosition openPosition;
        OrderExecType execType;
        bool isPartial;
        uint256 partialRatio;
        bytes32 key;
        uint256 positionRecordId;
        uint256 marginAssetId;
        uint256 sizeAbs;
        uint256 marginAbs;
        uint256 positionSize; // FIXME:
        int256 pnl;
    }

    function getOrderRequest(
        bool _isBuy,
        uint256 _marketId,
        uint256 _price,
        uint256 _orderIndex
    ) external view returns (OrderRequest memory) {
        if (_isBuy) {
            return buyOrderBook[_marketId][_price][_orderIndex];
        } else {
            return sellOrderBook[_marketId][_price][_orderIndex];
        }
    }

    function placeLimitOrder(OrderParams calldata p) external {
        // FIXME: orderSizeForPriceTick 업데이트
        // TODO: max cap 등 validation?
        // FIXME: TODO: Limit Order place or fill 할 때 traderBalance, poolAmount, reserveAmount 업데이트 필요

        OrderRequest memory orderRequest = OrderRequest(
            tx.origin,
            p._isLong,
            p._isIncrease,
            p._marketId,
            p._sizeAbs,
            p._marginAbs,
            p._limitPrice
        );

        pendingOrders[tx.origin][
            traderOrderRequestCounts[tx.origin]
        ] = orderRequest;
        traderOrderRequestCounts[tx.origin]++;

        bool _isBuy = p._isLong == p._isIncrease;

        if (_isBuy) {
            // TODO: do not update if outlier
            if (p._limitPrice > maxBidPrice[p._marketId]) {
                maxBidPrice[p._marketId] = p._limitPrice;
            }
        } else {
            if (
                p._limitPrice < minAskPrice[p._marketId] ||
                minAskPrice[p._marketId] == 0
            ) {
                minAskPrice[p._marketId] = p._limitPrice;
            }
        }
        // return order index
        enqueueOrderBook(orderRequest, _isBuy); // TODO: check - limit price should have validations for tick sizes
    }

    /**
     *
     * @param _isBuy used to determine which orderbook to iterate
     * @param _marketId index asset
     * @param _currentMarkPrice mark price from PriceManager before price impacts from limit orders execution
     * @return uint256  markPriceWithLimitOrderPriceImpact
     *
     * @dev iterate buy/sell orderbooks and execute limit orders until the mark price with price impact reaches the limit price levels.
     * primary iteration - while loop for limit price ticks in the orderbook
     * secondary iteration - for loop for orders in the limit price tick (First-In-First-Out)
     *
     * completely filled orders are removed from the orderbook
     * if the order is partially filled, the order is updated with the remaining size
     *
     */
    function executeLimitOrdersAndGetFinalMarkPrice(
        bool _isBuy,
        uint256 _marketId,
        uint256 _currentIndexPrice,
        uint256 _currentMarkPrice
    ) external onlyKeeper returns (uint256) {
        // FIXME: 주문 체결 후 호가 창 빌 때마다 maxBidPrice, minAskPrice 업데이트

        IterationContext memory ic;

        ic.interimMarkPrice = _currentMarkPrice; // initialize

        // uint256 _limitPriceIterator = maxBidPrice[_marketId]; // intialize

        ic.limitPriceIterator = _isBuy
            ? maxBidPrice[_marketId]
            : minAskPrice[_marketId]; // intialize

        ic.loopCondition = _isBuy
            ? ic.limitPriceIterator >= ic.interimMarkPrice
            : ic.limitPriceIterator < ic.interimMarkPrice;

        // TODO: maxBidPrice에 이상치가 있을 경우 처리
        // check - for the case the two values are equal?

        while (ic.loopCondition) {
            // check amounts of orders that can be filled in this price tick
            // if `sizeCap` amount of orders are filled, the mark price will reach `_limitPriceIterator`.
            // i.e. _interimMarkPrice + (price buffer) => _limitPriceIterator

            // then, the max amount of orders that can be filled in this price tick iteration is
            // min(sizeCap, orderSizeForPriceTick[_marketId][_limitPriceIterator])

            // PBC = PRICE_BUFFER_CHANGE_CONSTANT
            // _interimMarkPrice * PBC * (sizeCap) = (price shift) = (_limitPriceIterator - _interimMarkPrice)
            console.log("\n>>> >>> >>> While loop");
            console.log("maxBidPrice: ", maxBidPrice[_marketId]);
            console.log("minAskPrice: ", minAskPrice[_marketId]);

            PriceTickIterationContext memory ptc;

            if (orderSizeForPriceTick[_marketId][ic.limitPriceIterator] == 0) {
                // no order to execute for this limit price tick
                ic.limitPriceIterator = _isBuy
                    ? ic.limitPriceIterator + market.getPriceTickSize(_marketId)
                    : ic.limitPriceIterator -
                        market.getPriceTickSize(_marketId); // decrease for buy
                continue;
                // break;
            }

            // sizeCap = 이번 limit price tick에서 체결할 수 있는 최대 주문량
            // i.e. price impact가 발생하여 interimMarkPrice가 limitPriceIterator에 도달하는 경우
            // 하나의 price tick 안의 다 requests를 처리하고나면 sizeCap -= orderSizeInUsdForPriceTick[_marketId][_limitPriceIterator]

            // note: this is the right place for the variable `sizeCap` declaration +
            // `sizeCap` maintains its context within the while loop

            ptc.sizeCapInUsd =
                (_abs(
                    (ic.limitPriceIterator).toInt256() -
                        (ic.interimMarkPrice).toInt256()
                ) *
                    100000 *
                    100 *
                    1e20) / // 100000 USD per // 1% price buffer
                (ic.interimMarkPrice);

            ptc.sizeCap = _usdToToken(
                ptc.sizeCapInUsd,
                ic.limitPriceIterator,
                tokenInfo.getTokenDecimals(
                    market.getMarketInfo(_marketId).baseAssetId
                )
            );

            console.log(
                "\n>>> Enter Price Tick Iteration / sizeCapInUsd: ",
                ptc.sizeCapInUsd / 1e20,
                "USD"
            );
            console.log("Price: ", ic.limitPriceIterator / 1e20, "USD\n");

            ptc.isPartialForThePriceTick =
                ptc.sizeCap <
                orderSizeForPriceTick[_marketId][ic.limitPriceIterator];
            console.log(">>> isPartial:", ptc.isPartialForThePriceTick);

            ptc.fillAmount = ptc.isPartialForThePriceTick
                ? ptc.sizeCap // sizeCap 남아있는만큼 체결하고 종료
                : orderSizeForPriceTick[_marketId][ic.limitPriceIterator]; // fillAmount = 이번 price tick에서 체결할 주문량

            // 이번 price tick에서 발생할 price impact
            // price impact is calculated based on the index price
            // to avoid cumulative price impact
            ptc.priceImpactInUsd =
                (_currentIndexPrice * ptc.fillAmount) /
                (100000 * 100 * 1e20);

            console.log(">>> ptc.priceImpactInUsd: ", ptc.priceImpactInUsd);

            ptc.avgExecutionPrice = _getAvgExecutionPrice(
                ic.interimMarkPrice,
                ptc.priceImpactInUsd,
                _isBuy
            );

            // _orderRequest[i].sizeAbs > sizeCap => isPartial = true

            mapping(uint256 => OrderRequest) storage _orderRequests = _isBuy
                ? buyOrderBook[_marketId][ic.limitPriceIterator]
                : sellOrderBook[_marketId][ic.limitPriceIterator];

            ptc.firstIdx = _isBuy
                ? buyFirstIndex[_marketId][ic.limitPriceIterator]
                : sellFirstIndex[_marketId][ic.limitPriceIterator];

            ptc.lastIdx = _isBuy
                ? buyLastIndex[_marketId][ic.limitPriceIterator]
                : sellLastIndex[_marketId][ic.limitPriceIterator];

            // console.log("^^^^^ ptc.firstIdx: ", ptc.firstIdx); // FIXME:
            // console.log("^^^^^ ptc.lastIdx: ", ptc.lastIdx);

            for (uint256 i = ptc.firstIdx; i <= ptc.lastIdx; i++) {
                // console.log(">>> chkpt 3");
                // console.log(">>> i: ", i);

                // TODO: pendingOrders에서 제거 - 필요한 기능인지 점검
                // TODO: validateExecution here (increase, decrease)

                OrderRequest memory request = _orderRequests[i];

                executeLimitOrder(
                    request,
                    ptc.avgExecutionPrice,
                    ptc.sizeCap,
                    _isBuy
                );

                if (ptc.sizeCap == 0) {
                    break;
                }
            }

            if (ptc.isPartialForThePriceTick) {
                console.log(">>> Exit: Partial Order");
                break;
            } else {
                // If `isPartial = false` and all the orders in the price tick are filled (empty order book for the price tick),
                // update the maxBidPrice or minAskPrice
                if (
                    buyFirstIndex[_marketId][ic.limitPriceIterator] == 0 ||
                    buyLastIndex[_marketId][ic.limitPriceIterator] == 0
                ) {
                    if (_isBuy) {
                        maxBidPrice[_marketId] =
                            ic.limitPriceIterator -
                            market.getPriceTickSize(_marketId);
                    } else {
                        minAskPrice[_marketId] =
                            ic.limitPriceIterator +
                            market.getPriceTickSize(_marketId);
                    }
                }
            }
            // Note: if `isPartial = true` in this while loop,  sizeCap will be 0 after the for loop

            ic.interimMarkPrice = _isBuy
                ? ic.interimMarkPrice + ptc.priceImpactInUsd
                : ic.interimMarkPrice - ptc.priceImpactInUsd; // 이번 price tick 주문 iteration 이후 Price Impact를 interimPrice에 적용

            ic.limitPriceIterator = _isBuy
                ? ic.limitPriceIterator - market.getPriceTickSize(_marketId)
                : ic.limitPriceIterator + market.getPriceTickSize(_marketId); // next iteration; decrease for buy

            // update while loop condition for the next iteration
            ic.loopCondition = _isBuy
                ? ic.limitPriceIterator >= ic.interimMarkPrice
                : ic.limitPriceIterator < ic.interimMarkPrice;

            console.log(
                "+++++++++ limitPriceIterator: ",
                ic.limitPriceIterator
            );
            console.log("+++++++++ interimMarkPrice: ", ic.interimMarkPrice);
            console.log("+++++++++ updated loopCondition: ", ic.loopCondition);
        }

        return ic.interimMarkPrice; // price impact (buffer size)
    }

    function executeLimitOrder(
        OrderRequest memory _request,
        uint256 _avgExecPrice,
        uint256 sizeCap,
        bool _isBuy // bool isPartial
    ) private {
        FillLimitOrderContext memory flc;

        flc.marginAssetId = market
            .getMarketInfo(_request.marketId)
            .marginAssetId;

        flc.isPartial = _request.sizeAbs > sizeCap;
        flc.partialRatio = flc.isPartial
            ? (sizeCap / _request.sizeAbs) * PARTIAL_RATIO_PRECISION
            : 1 * PARTIAL_RATIO_PRECISION;

        flc.sizeAbs = flc.isPartial ? sizeCap : _request.sizeAbs;

        flc.marginAbs = flc.isPartial
            ? (_request.marginAbs * flc.partialRatio) / PARTIAL_RATIO_PRECISION
            : _request.marginAbs;

        // update position
        flc.key = _getPositionKey(
            _request.trader,
            _request.isLong,
            _request.marketId
        );

        // TODO: validations

        flc.openPosition = positionVault.getPosition(flc.key);

        // Execution type 1: open position
        if (flc.openPosition.size == 0 && _request.isIncrease) {
            flc.execType = OrderExecType.OpenPosition;

            _executeIncreasePosition(flc.execType, _request, flc);
        }

        // Execution type 2: increase position (update existing position)
        if (flc.openPosition.size > 0 && _request.isIncrease) {
            flc.execType = OrderExecType.IncreasePosition;

            _executeIncreasePosition(flc.execType, _request, flc);
        }

        // Execution type 3: decrease position
        if (
            flc.openPosition.size > 0 &&
            !_request.isIncrease &&
            flc.sizeAbs != flc.openPosition.size
        ) {
            flc.execType = OrderExecType.DecreasePosition;

            _executeDecreasePosition(flc.execType, _request, flc);
        }

        // Execution type 4: close position
        if (
            flc.openPosition.size > 0 &&
            !_request.isIncrease &&
            flc.sizeAbs == flc.openPosition.size
        ) {
            flc.execType = OrderExecType.ClosePosition;

            _executeDecreasePosition(flc.execType, _request, flc);
        }

        // create order record
        orderHistory.createOrderRecord(
            CreateOrderRecordParams(
                msg.sender,
                OrderType.Limit,
                _request.isLong,
                _request.isIncrease,
                flc.positionRecordId,
                _request.marketId,
                _request.sizeAbs,
                _request.marginAbs,
                _request.limitPrice // TODO: check - also applying avgExecPrice for Limit Orders?
            )
        );

        if (_request.isLong) {
            globalState.updateGlobalLongPositionState(
                UpdateGlobalPositionStateParams(
                    _request.isIncrease,
                    _request.marketId,
                    flc.sizeAbs,
                    flc.marginAbs,
                    _avgExecPrice
                )
            );
        } else {
            globalState.updateGlobalShortPositionState(
                UpdateGlobalPositionStateParams(
                    _request.isIncrease,
                    _request.marketId,
                    flc.sizeAbs,
                    flc.marginAbs,
                    _avgExecPrice
                )
            );
        }

        sizeCap -= flc.sizeAbs; // TODO: validation - assert(sum(request.sizeAbs) == orderSizeInUsdForPriceTick[_marketId][_limitPriceIterator])

        // delete or update (isPartial) limit order from the orderbook
        if (flc.isPartial) {
            _request.sizeAbs -= flc.sizeAbs;
            _request.marginAbs -= flc.marginAbs;
        } else {
            dequeueOrderBook(_request, _isBuy); // TODO: check - if the target order is the first one in the queue
        }
    }

    function _executeIncreasePosition(
        OrderExecType execType,
        OrderRequest memory _request,
        FillLimitOrderContext memory flc
    ) private {
        traderVault.decreaseTraderBalance(
            msg.sender,
            flc.marginAssetId,
            flc.marginAbs
        );

        _request.isLong
            ? risePool.increaseLongReserveAmount(flc.marginAssetId, flc.sizeAbs)
            : risePool.increaseShortReserveAmount(
                flc.marginAssetId,
                flc.sizeAbs
            );

        if (execType == OrderExecType.OpenPosition) {
            /// @dev for OpenPosition: PositionRecord => OpenPosition

            flc.positionRecordId = positionHistory.openPositionRecord(
                OpenPositionRecordParams(
                    msg.sender,
                    _request.marketId,
                    flc.sizeAbs,
                    _request.limitPrice,
                    0
                )
            );

            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    execType,
                    flc.key,
                    true, // isOpening
                    msg.sender,
                    _request.isLong,
                    flc.positionRecordId,
                    _request.marketId,
                    _request.limitPrice,
                    flc.sizeAbs,
                    _request.marginAbs,
                    _request.isIncrease, // isIncreaseInSize
                    _request.isIncrease // isIncreaseInMargin
                )
            );
        } else if (execType == OrderExecType.IncreasePosition) {
            /// @dev for IncreasePosition: OpenPosition => PositionRecord

            flc.positionRecordId = flc.openPosition.currentPositionRecordId;

            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    execType,
                    flc.key,
                    false, // isOpening
                    msg.sender,
                    _request.isLong,
                    flc.positionRecordId,
                    _request.marketId,
                    _request.limitPrice,
                    flc.sizeAbs,
                    _request.marginAbs,
                    _request.isIncrease, // isIncreaseInSize
                    _request.isIncrease // isIncreaseInMargin
                )
            );

            positionHistory.updatePositionRecord(
                UpdatePositionRecordParams(
                    msg.sender,
                    flc.key,
                    flc.positionRecordId,
                    _request.isIncrease,
                    flc.pnl,
                    flc.sizeAbs,
                    _request.limitPrice
                )
            );
        } else {
            revert("Invalid execution type");
        }
    }

    function _executeDecreasePosition(
        OrderExecType execType,
        OrderRequest memory _request,
        FillLimitOrderContext memory flc
    ) private {
        // PnL settlement
        flc.pnl = settlePnL(
            flc.openPosition,
            _request.isLong,
            _request.limitPrice,
            _request.marketId,
            flc.sizeAbs,
            _request.marginAbs
        );

        flc.positionRecordId = flc.openPosition.currentPositionRecordId;

        if (execType == OrderExecType.DecreasePosition) {
            UpdatePositionParams memory params = UpdatePositionParams(
                execType,
                flc.key,
                false, // isOpening
                msg.sender,
                _request.isLong,
                flc.positionRecordId,
                _request.marketId,
                _request.limitPrice,
                flc.sizeAbs,
                _request.marginAbs,
                _request.isIncrease, // isIncreaseInSize
                _request.isIncrease // isIncreaseInMargin
            );

            // positionVault.updateOpenPositionWithPnl(0, params); // FIXME: first arg is interimPnlUsd
            positionVault.updateOpenPosition(params);

            positionHistory.updatePositionRecord(
                UpdatePositionRecordParams(
                    msg.sender,
                    flc.key,
                    flc.openPosition.currentPositionRecordId,
                    _request.isIncrease,
                    flc.pnl,
                    flc.sizeAbs,
                    _request.limitPrice
                )
            );
        } else if (execType == OrderExecType.ClosePosition) {
            positionVault.deleteOpenPosition(flc.key);

            positionHistory.closePositionRecord(
                ClosePositionRecordParams(
                    msg.sender,
                    flc.openPosition.currentPositionRecordId,
                    flc.pnl,
                    flc.sizeAbs,
                    _request.limitPrice
                )
            );
        } else {
            revert("Invalid execution type");
        }
    }
}
