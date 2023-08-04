// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./OrderBookBase.sol";
import "../global/GlobalState.sol";
import "../market/TokenInfo.sol";
import "../order/OrderUtils.sol";
import "../position/PositionHistory.sol";
import "../position/PositionVault.sol";
import "../position/PnlManager.sol";
import "../common/Modifiers.sol";
import "../common/MathUtils.sol";
import "../common/constants.sol";
import "../common/params.sol";

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
    GlobalState public globalState;
    TokenInfo public tokenInfo;

    struct IterationContext {
        bool loopCondition;
        uint256 interimMarkPrice;
        uint256 limitPriceIterator;
    }

    struct PriceTickIterationContext {
        bool _isPartialForThePriceTick;
        uint256 _sizeCap;
        uint256 _sizeCapInUsd;
        uint256 _fillAmount;
        uint256 _priceImpactInUsd;
        uint256 _avgExecutionPrice;
        uint256 _firstIdx;
        uint256 _lastIdx;
    }

    struct FillLimitOrderContext {
        OrderExecType _execType;
        OpenPosition _openPosition;
        bool _isPartial;
        bytes32 _key;
        int256 _pnl;
        uint256 _marginAssetId;
        uint256 _partialRatio;
        uint256 _sizeAbs;
        uint256 _marginAbs;
        uint256 _positionSize;
        uint256 _positionRecordId;
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

    function placeLimitOrder(OrderContext calldata c) external {
        // FIXME: orderSizeForPriceTick 업데이트
        // TODO: max cap 등 validation?
        // FIXME: TODO: Limit Order place or fill 할 때 traderBalance, poolAmount, reserveAmount 업데이트 필요

        OrderRequest memory orderRequest = OrderRequest(
            tx.origin,
            c._isLong,
            c._isIncrease,
            c._marketId,
            c._sizeAbs,
            c._marginAbs,
            c._limitPrice
        );

        pendingOrders[tx.origin][
            traderOrderRequestCounts[tx.origin]
        ] = orderRequest;
        traderOrderRequestCounts[tx.origin]++;

        bool _isBuy = c._isLong == c._isIncrease;

        if (_isBuy) {
            // TODO: do not update if outlier
            if (c._limitPrice > maxBidPrice[c._marketId]) {
                maxBidPrice[c._marketId] = c._limitPrice;
            }
        } else {
            if (
                c._limitPrice < minAskPrice[c._marketId] ||
                minAskPrice[c._marketId] == 0
            ) {
                minAskPrice[c._marketId] = c._limitPrice;
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
            // if `_sizeCap` amount of orders are filled, the mark price will reach `_limitPriceIterator`.
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

            // _sizeCap = 이번 limit price tick에서 체결할 수 있는 최대 주문량
            // i.e. price impact가 발생하여 interimMarkPrice가 limitPriceIterator에 도달하는 경우
            // 하나의 price tick 안의 다 requests를 처리하고나면 _sizeCap -= orderSizeInUsdForPriceTick[_marketId][_limitPriceIterator]

            // note: this is the right place for the variable `_sizeCap` declaration +
            // `_sizeCap` maintains its context within the while loop

            ptc._sizeCapInUsd =
                (_abs(
                    (ic.limitPriceIterator).toInt256() -
                        (ic.interimMarkPrice).toInt256()
                ) *
                    100000 *
                    100 *
                    1e20) / // 100000 USD per // 1% price buffer
                (ic.interimMarkPrice);

            ptc._sizeCap = _usdToToken(
                ptc._sizeCapInUsd,
                ic.limitPriceIterator,
                tokenInfo.getTokenDecimals(
                    market.getMarketInfo(_marketId).baseAssetId
                )
            );

            console.log(
                "\n>>> Enter Price Tick Iteration / sizeCapInUsd: ",
                ptc._sizeCapInUsd / 1e20,
                "USD"
            );
            console.log("Price: ", ic.limitPriceIterator / 1e20, "USD\n");

            ptc._isPartialForThePriceTick =
                ptc._sizeCap <
                orderSizeForPriceTick[_marketId][ic.limitPriceIterator];
            console.log(">>> isPartial:", ptc._isPartialForThePriceTick);

            ptc._fillAmount = ptc._isPartialForThePriceTick
                ? ptc._sizeCap // _sizeCap 남아있는만큼 체결하고 종료
                : orderSizeForPriceTick[_marketId][ic.limitPriceIterator]; // _fillAmount = 이번 price tick에서 체결할 주문량

            // 이번 price tick에서 발생할 price impact
            // price impact is calculated based on the index price
            // to avoid cumulative price impact
            ptc._priceImpactInUsd =
                (_currentIndexPrice * ptc._fillAmount) /
                (100000 * 100 * 1e20);

            console.log(">>> ptc._priceImpactInUsd: ", ptc._priceImpactInUsd);

            ptc._avgExecutionPrice = _getAvgExecutionPrice(
                ic.interimMarkPrice,
                ptc._priceImpactInUsd,
                _isBuy
            );

            // _orderRequest[i].sizeAbs > _sizeCap => isPartial = true

            mapping(uint256 => OrderRequest) storage _orderRequests = _isBuy
                ? buyOrderBook[_marketId][ic.limitPriceIterator]
                : sellOrderBook[_marketId][ic.limitPriceIterator];

            ptc._firstIdx = _isBuy
                ? buyFirstIndex[_marketId][ic.limitPriceIterator]
                : sellFirstIndex[_marketId][ic.limitPriceIterator];

            ptc._lastIdx = _isBuy
                ? buyLastIndex[_marketId][ic.limitPriceIterator]
                : sellLastIndex[_marketId][ic.limitPriceIterator];

            // console.log("^^^^^ ptc._firstIdx: ", ptc._firstIdx); // FIXME:
            // console.log("^^^^^ ptc._lastIdx: ", ptc._lastIdx);

            for (uint256 i = ptc._firstIdx; i <= ptc._lastIdx; i++) {
                // console.log(">>> chkpt 3");
                // console.log(">>> i: ", i);

                // TODO: pendingOrders에서 제거 - 필요한 기능인지 점검
                // TODO: validateExecution here (increase, decrease)

                OrderRequest memory request = _orderRequests[i];
                executeLimitOrder(
                    request,
                    ptc._avgExecutionPrice,
                    ptc._sizeCap,
                    _isBuy
                );

                if (ptc._sizeCap == 0) {
                    break;
                }
            }

            if (ptc._isPartialForThePriceTick) {
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
            // Note: if `isPartial = true` in this while loop,  _sizeCap will be 0 after the for loop

            ic.interimMarkPrice = _isBuy
                ? ic.interimMarkPrice + ptc._priceImpactInUsd
                : ic.interimMarkPrice - ptc._priceImpactInUsd; // 이번 price tick 주문 iteration 이후 Price Impact를 interimPrice에 적용

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
        uint256 _sizeCap,
        bool _isBuy // bool _isPartial
    ) private {
        FillLimitOrderContext memory flc;

        flc._marginAssetId = market
            .getMarketInfo(_request.marketId)
            .marginAssetId;

        flc._isPartial = _request.sizeAbs > _sizeCap;
        flc._partialRatio = flc._isPartial
            ? (_sizeCap / _request.sizeAbs) * PARTIAL_RATIO_PRECISION
            : 1 * PARTIAL_RATIO_PRECISION;

        flc._sizeAbs = flc._isPartial ? _sizeCap : _request.sizeAbs;

        flc._marginAbs = flc._isPartial
            ? (_request.marginAbs * flc._partialRatio) / PARTIAL_RATIO_PRECISION
            : _request.marginAbs;

        // update position
        flc._key = _getPositionKey(
            _request.trader,
            _request.isLong,
            _request.marketId
        );

        flc._openPosition = positionVault.getPosition(flc._key);

        // Execution type 1: open position
        if (flc._openPosition.size == 0 && _request.isIncrease) {
            flc._execType = OrderExecType.OpenPosition;

            _executeIncreasePosition(flc._execType, _request, flc);
        }

        // Execution type 2: increase position (update existing position)
        if (flc._openPosition.size > 0 && _request.isIncrease) {
            flc._execType = OrderExecType.IncreasePosition;

            _executeIncreasePosition(flc._execType, _request, flc);
        }

        // Execution type 3: decrease position
        if (
            flc._openPosition.size > 0 &&
            !_request.isIncrease &&
            flc._sizeAbs != flc._openPosition.size
        ) {
            flc._execType = OrderExecType.DecreasePosition;

            _executeDecreasePosition(flc._execType, _request, flc);
        }

        // Execution type 4: close position
        if (
            flc._openPosition.size > 0 &&
            !_request.isIncrease &&
            flc._sizeAbs == flc._openPosition.size
        ) {
            flc._execType = OrderExecType.ClosePosition;

            _executeDecreasePosition(flc._execType, _request, flc);
        }

        if (_request.isLong) {
            globalState.updateGlobalLongPositionState(
                _request.isIncrease,
                _request.marketId,
                flc._sizeAbs,
                flc._marginAbs,
                _avgExecPrice
            );
        } else {
            globalState.updateGlobalShortPositionState(
                _request.isIncrease,
                _request.marketId,
                flc._sizeAbs,
                flc._marginAbs,
                _avgExecPrice
            );
        }

        _sizeCap -= flc._sizeAbs; // TODO: validation - assert(sum(request.sizeAbs) == orderSizeInUsdForPriceTick[_marketId][_limitPriceIterator])

        // delete or update (isPartial) limit order from the orderbook
        if (flc._isPartial) {
            _request.sizeAbs -= flc._sizeAbs;
            _request.marginAbs -= flc._marginAbs;
        } else {
            dequeueOrderBook(_request, _isBuy); // TODO: check - if the target order is the first one in the queue
        }
    }

    function _executeIncreasePosition(
        OrderExecType _execType,
        OrderRequest memory _request,
        FillLimitOrderContext memory flc
    ) private {
        traderVault.decreaseTraderBalance(
            msg.sender,
            flc._marginAssetId,
            flc._marginAbs
        );

        _request.isLong
            ? risePool.increaseLongReserveAmount(
                flc._marginAssetId,
                flc._sizeAbs
            )
            : risePool.increaseShortReserveAmount(
                flc._marginAssetId,
                flc._sizeAbs
            );

        if (_execType == OrderExecType.OpenPosition) {
            /// @dev for OpenPosition: PositionRecord => OpenPosition

            flc._positionRecordId = positionHistory.openPositionRecord(
                msg.sender,
                _request.marketId,
                flc._sizeAbs,
                _request.limitPrice,
                0
            );

            UpdatePositionParams memory params = UpdatePositionParams(
                _execType,
                flc._key,
                true, // isOpening
                msg.sender,
                _request.isLong,
                flc._positionRecordId,
                _request.marketId,
                _request.limitPrice,
                flc._sizeAbs,
                _request.marginAbs,
                _request.isIncrease, // isIncreaseInSize
                _request.isIncrease // isIncreaseInMargin
            );

            positionVault.updateOpenPosition(params);
        } else if (_execType == OrderExecType.IncreasePosition) {
            /// @dev for IncreasePosition: OpenPosition => PositionRecord

            flc._positionRecordId = flc._openPosition.currentPositionRecordId;

            UpdatePositionParams memory params = UpdatePositionParams(
                _execType,
                flc._key,
                false, // isOpening
                msg.sender,
                _request.isLong,
                flc._positionRecordId,
                _request.marketId,
                _request.limitPrice,
                flc._sizeAbs,
                _request.marginAbs,
                _request.isIncrease, // isIncreaseInSize
                _request.isIncrease // isIncreaseInMargin
            );

            positionVault.updateOpenPosition(params);

            positionHistory.updatePositionRecord(
                msg.sender,
                flc._key,
                flc._positionRecordId,
                _request.isIncrease,
                flc._pnl,
                flc._sizeAbs,
                _request.limitPrice
            );
        } else {
            revert("Invalid execution type");
        }
    }

    function _executeDecreasePosition(
        OrderExecType _execType,
        OrderRequest memory _request,
        FillLimitOrderContext memory flc
    ) private {
        // PnL settlement
        settlePnL(
            flc._openPosition,
            _request.isLong,
            _request.limitPrice,
            _request.marketId,
            flc._sizeAbs,
            _request.marginAbs
        );

        flc._positionRecordId = flc._openPosition.currentPositionRecordId;

        if (_execType == OrderExecType.DecreasePosition) {
            UpdatePositionParams memory params = UpdatePositionParams(
                _execType,
                flc._key,
                false, // isOpening
                msg.sender,
                _request.isLong,
                flc._positionRecordId,
                _request.marketId,
                _request.limitPrice,
                flc._sizeAbs,
                _request.marginAbs,
                _request.isIncrease, // isIncreaseInSize
                _request.isIncrease // isIncreaseInMargin
            );

            // positionVault.updateOpenPositionWithPnl(0, params); // FIXME: first arg is interimPnlUsd
            positionVault.updateOpenPosition(params);

            positionHistory.updatePositionRecord(
                msg.sender,
                flc._key,
                flc._openPosition.currentPositionRecordId,
                _request.isIncrease,
                flc._pnl,
                flc._sizeAbs,
                _request.limitPrice
            );
        } else if (_execType == OrderExecType.ClosePosition) {
            positionVault.deleteOpenPosition(flc._key);

            positionHistory.closePositionRecord(
                msg.sender,
                flc._openPosition.currentPositionRecordId,
                flc._pnl,
                flc._sizeAbs,
                _request.limitPrice
            );
        } else {
            revert("Invalid execution type");
        }
    }
}
