// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OrderBookBase.sol";
import "../interfaces/l3/IL3Vault.sol";
import "../interfaces/l3/IOrderBook.sol";

contract OrderBook is IOrderBook, OrderBookBase {
    IL3Vault public l3Vault;

    struct IterationContext {
        uint256 interimMarkPrice;
        uint256 limitPriceIterator;
        bool loopCondition;
    }

    struct PriceTickIterationContext {
        uint256 _sizeCap;
        bool _isPartialForThePriceTick;
        uint256 _fillAmount;
        uint256 _priceImpactInUsd;
        uint256 _avgExecutionPrice;
        uint256 _firstIdx;
        uint256 _lastIdx;
    }

    struct FillLimitOrderContext {
        bool _isPartial;
        uint256 _partialRatio;
        uint256 _sizeAbsInUsd;
        uint256 _collateralAbsInUsd;
        uint256 _positionSizeInUsd;
    }

    constructor(address _l3Vault) {
        l3Vault = IL3Vault(_l3Vault);
    }

    function getOrderRequest(bool _isBuy, uint256 _indexAssetId, uint256 _price, uint256 _orderIndex)
        external
        view
        returns (OrderRequest memory)
    {
        if (_isBuy) {
            return buyOrderBook[_indexAssetId][_price][_orderIndex];
        } else {
            return sellOrderBook[_indexAssetId][_price][_orderIndex];
        }
    }

    function placeLimitOrder(IL3Vault.OrderContext calldata c) external {
        // FIXME: orderSizeForPriceTick 업데이트

        OrderRequest memory orderRequest = OrderRequest(
            tx.origin,
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._collateralAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            c._limitPrice
        );

        pendingOrders[tx.origin][
            traderOrderRequestCounts[tx.origin]
        ] = orderRequest;
        traderOrderRequestCounts[tx.origin]++;

        bool _isBuy = c._isLong == c._isIncrease;

        if (_isBuy) {
            if (c._limitPrice > maxBidPrice[c._indexAssetId]) {
                maxBidPrice[c._indexAssetId] = c._limitPrice;
            }
        } else {
            if (
                c._limitPrice < minAskPrice[c._indexAssetId] ||
                minAskPrice[c._indexAssetId] == 0
            ) {
                minAskPrice[c._indexAssetId] = c._limitPrice;
            }
        }
        // return order index
        enqueueOrderBook(orderRequest, _isBuy); // TODO: check - limit price should have validations for tick sizes
    }

    /**
     *
     * @param _isBuy used to determine which orderbook to iterate
     * @param _indexAssetId index asset
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
        uint256 _indexAssetId,
        uint256 _currentIndexPrice,
        uint256 _currentMarkPrice
    ) external onlyKeeper returns (uint256) {
        // FIXME: 주문 체결 후 호가 창 빌 때마다 maxBidPrice, minAskPrice 업데이트

        IterationContext memory ic;

        ic.interimMarkPrice = _currentMarkPrice; // initialize

        // uint256 _limitPriceIterator = maxBidPrice[_indexAssetId]; // intialize

        ic.limitPriceIterator = _isBuy
            ? maxBidPrice[_indexAssetId]
            : minAskPrice[_indexAssetId]; // intialize

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
            // min(sizeCap, orderSizeForPriceTick[_indexAssetId][_limitPriceIterator])

            // PBC = PRICE_BUFFER_CHANGE_CONSTANT
            // _interimMarkPrice * PBC * (sizeCap) = (price shift) = (_limitPriceIterator - _interimMarkPrice)

            PriceTickIterationContext memory ptc;

            if (
                orderSizeInUsdForPriceTick[_indexAssetId][
                    ic.limitPriceIterator
                ] == 0
            ) {
                // no order to execute for this limit price tick
                ic.limitPriceIterator = _isBuy
                    ? ic.limitPriceIterator + priceTickSizes[_indexAssetId]
                    : ic.limitPriceIterator - priceTickSizes[_indexAssetId]; // decrease for buy
                continue;
            }

            // _sizeCap = 이번 limit price tick에서 체결할 수 있는 최대 주문량
            // i.e. price impact가 발생하여 interimMarkPrice가 limitPriceIterator에 도달하는 경우
            // 하나의 price tick 안의 다 requests를 처리하고나면 _sizeCap -= orderSizeInUsdForPriceTick[_indexAssetId][_limitPriceIterator]

            // note: this is the right place for the variable `_sizeCap` declaration
            // `_sizeCap` maintains its context within the while loop
            ptc._sizeCap =
                _abs(
                    int256(ic.limitPriceIterator) - int256(ic.interimMarkPrice)
                ) /
                (ic.interimMarkPrice * uint256(PRICE_BUFFER_DELTA_TO_SIZE)); // TODO: decimals 확인

            ptc._isPartialForThePriceTick =
                ptc._sizeCap <
                orderSizeInUsdForPriceTick[_indexAssetId][
                    ic.limitPriceIterator
                ];

            ptc._fillAmount = ptc._isPartialForThePriceTick
                ? ptc._sizeCap // _sizeCap 남아있는만큼 체결하고 종료
                : orderSizeInUsdForPriceTick[_indexAssetId][
                    ic.limitPriceIterator
                ]; // _fillAmount = 이번 price tick에서 체결할 주문량

            // 이번 price tick에서 발생할 price impact
            // price impact is calculated based on the index price
            // to avoid cumulative price impact
            ptc._priceImpactInUsd =
                _currentIndexPrice *
                uint256(PRICE_BUFFER_DELTA_TO_SIZE) *
                ptc._fillAmount;

            ptc._avgExecutionPrice = _getAvgExecutionPrice(
                ic.interimMarkPrice,
                ptc._priceImpactInUsd,
                _isBuy
            );

            // _orderRequest[i].sizeAbs > _sizeCap => isPartial = true

            mapping(uint256 => OrderRequest) storage _orderRequests = _isBuy
                ? buyOrderBook[_indexAssetId][ic.limitPriceIterator]
                : sellOrderBook[_indexAssetId][ic.limitPriceIterator];

            ptc._firstIdx = _isBuy
                ? buyFirstIndex[_indexAssetId][ic.limitPriceIterator]
                : sellFirstIndex[_indexAssetId][ic.limitPriceIterator];

            ptc._lastIdx = _isBuy
                ? buyLastIndex[_indexAssetId][ic.limitPriceIterator]
                : sellLastIndex[_indexAssetId][ic.limitPriceIterator];

            for (uint256 i = ptc._firstIdx; i <= ptc._lastIdx; i++) {
                // TODO: pendingOrders에서 제거 - 필요한 기능인지 점검
                // TODO: validateExecution here (increase, decrease)

                OrderRequest memory request = _orderRequests[i];

                _fillLimitOrder(
                    request,
                    ptc._avgExecutionPrice,
                    ptc._sizeCap,
                    _isBuy
                );

                if (ptc._sizeCap == 0) {
                    break;
                }
            }

            ic.interimMarkPrice = _isBuy
                ? ic.interimMarkPrice + ptc._priceImpactInUsd
                : ic.interimMarkPrice - ptc._priceImpactInUsd; // 이번 price tick 주문 iteration 이후 Price Impact를 interimPrice에 적용

            // _sizeCap -= orderSizeInUsdForPriceTick[_indexAssetId][
            //     _limitPriceIterator
            // ];
            ic.limitPriceIterator = _isBuy
                ? ic.limitPriceIterator - priceTickSizes[_indexAssetId]
                : ic.limitPriceIterator + priceTickSizes[_indexAssetId]; // next iteration; decrease for buy

            // update while loop condition for the next iteration
            ic.loopCondition = _isBuy
                ? ic.limitPriceIterator >= ic.interimMarkPrice
                : ic.limitPriceIterator < ic.interimMarkPrice;

            if (ptc._isPartialForThePriceTick) {
                break;
            }
            // Note: if `isPartial = true` in this while loop,  _sizeCap will be 0 after the for loop
        }
        return ic.interimMarkPrice; // price impact (buffer size)
    }

    function _fillLimitOrder(
        OrderRequest memory _request,
        uint256 _avgExecutionPrice,
        uint256 _sizeCap,
        bool _isBuy // bool _isPartial
    ) internal {
        FillLimitOrderContext memory floc;

        floc._isPartial = _request.sizeAbsInUsd > _sizeCap;
        floc._partialRatio = floc._isPartial
            ? (_sizeCap / _request.sizeAbsInUsd) * PARTIAL_RATIO_PRECISION
            : 1 * PARTIAL_RATIO_PRECISION;
        // uint256 _sizeAbsInUsd = _isPartial
        //     ? _request.sizeAbsInUsd - _sizeCap
        //     : _request.sizeAbsInUsd;

        floc._sizeAbsInUsd = floc._isPartial ? _sizeCap : _request.sizeAbsInUsd;

        floc._collateralAbsInUsd = floc._isPartial
            ? (_request.collateralAbsInUsd * floc._partialRatio) /
                PARTIAL_RATIO_PRECISION
            : _request.collateralAbsInUsd;

        // update filledOrders
        l3Vault.fillOrder(
            _request.trader,
            false, // isMarketOrder
            _request.isLong,
            _request.isIncrease,
            _request.indexAssetId,
            _request.collateralAssetId,
            floc._sizeAbsInUsd,
            floc._collateralAbsInUsd,
            _avgExecutionPrice
        );

        // filledOrders[_request.trader][
        //     traderFilledOrderCounts[_request.trader]
        // ] = FilledOrder(
        //     false,
        //     _request.isLong,
        //     _request.isIncrease,
        //     _request.indexAssetId,
        //     _request.collateralAssetId,
        //     _sizeAbsInUsd,
        //     _collateralAbsInUsd,
        //     _avgExecutionPrice
        // );
        // traderFilledOrderCounts[_request.trader] += 1;

        // update position
        bytes32 key = _getPositionKey(
            _request.trader,
            _request.isLong,
            _request.indexAssetId,
            _request.collateralAssetId
        );
        // Position {size, collateralSizeInUsd, avgOpenPrice, lastUpdatedTime}
        if (_request.isIncrease) {
            l3Vault.updatePosition(
                key,
                _avgExecutionPrice,
                floc._sizeAbsInUsd,
                floc._collateralAbsInUsd,
                true, // isIncreaseInSize
                true // isIncreaseInCollateral
            );
        } else {
            // position 업데이트
            // PnL 계산, trader balance, poolAmounts, reservedAmounts 업데이트
            // position 삭제 검사

            l3Vault.settlePnL(
                key,
                _request.isLong,
                _avgExecutionPrice,
                _request.indexAssetId,
                _request.collateralAssetId,
                floc._sizeAbsInUsd,
                floc._collateralAbsInUsd
            );

            floc._positionSizeInUsd = l3Vault.getPositionSizeInUsd(key);

            if (floc._sizeAbsInUsd == floc._positionSizeInUsd) {
                l3Vault.deletePosition(key);
            } else {
                l3Vault.updatePosition(
                    key,
                    _avgExecutionPrice,
                    floc._sizeAbsInUsd,
                    floc._collateralAbsInUsd,
                    false,
                    false
                );
            }
        }

        l3Vault.updateGlobalPositionState(
            _request.isLong,
            _request.isIncrease,
            _request.indexAssetId,
            floc._sizeAbsInUsd,
            floc._collateralAbsInUsd,
            _avgExecutionPrice
        );

        _sizeCap -= floc._sizeAbsInUsd; // TODO: validation - assert(sum(request.sizeAbs) == orderSizeInUsdForPriceTick[_indexAssetId][_limitPriceIterator])

        // delete or update (isPartial) limit order
        if (floc._isPartial) {
            _request.sizeAbsInUsd -= floc._sizeAbsInUsd;
            _request.collateralAbsInUsd -= floc._collateralAbsInUsd;
        } else {
            dequeueOrderBook(_request, _isBuy); // TODO: check - if the target order is the first one in the queue
        }
    }
}
