// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol"; // test-only
import "./interfaces/IPriceManager.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ArbSys.sol";

contract L3Vault {
    // ---------------------------------------------------- States ----------------------------------------------------
    IPriceManager public priceManager;

    int public constant PRICE_BUFFER_PRECISION = 10 ** 6;
    int public constant SIZE_PRECISION = 10 ** 3;
    int public constant DECAY_CONSTANT = (PRICE_BUFFER_PRECISION / 100) / 300; // 1% decay per 5 miniutes
    int public constant PRICE_BUFFER_CHANGE_CONSTANT =
        ((10 ** 6) * SIZE_PRECISION) / (PRICE_BUFFER_PRECISION / 100); // 1% price buffer per 10^6 USD

    uint256 public constant usdDecimals = 8;
    uint256 public constant USD_ID = 0;
    uint256 public constant ETH_ID = 1;
    uint256 private constant assetIdCounter = 1; // temporary
    mapping(uint256 => uint256) public tokenDecimals; // TODO: listing restriction needed

    struct OrderContext {
        bool _isLong;
        bool _isIncrease;
        uint256 _indexAssetId;
        uint256 _collateralAssetId;
        uint256 _sizeAbsInUsd;
        uint256 _collateralAbsInUsd;
        uint256 _limitPrice; // empty for market orders
    }

    struct OrderRequest {
        address trader;
        bool isLong;
        bool isIncrease;
        uint256 indexAssetId; // redundant?
        uint256 collateralAssetId;
        uint256 sizeAbsInUsd;
        uint256 collateralAbsInUsd;
        uint256 limitPrice;
    }

    struct FilledOrder {
        bool isMarketOrder;
        bool isLong;
        bool isIncrease;
        uint256 indexAssetId;
        uint256 collateralAssetId;
        uint256 sizeAbsInUsd;
        uint256 collateralAbsInUsd;
        uint256 executionPrice;
    }

    struct Position {
        uint256 sizeInUsd;
        uint256 collateralInUsd;
        uint256 avgOpenPrice; // TODO: check - should be coupled w/ positions link logic
        uint256 lastUpdatedTime; // Currently not used for any validation
    }

    struct GlobalPositionState {
        uint256 totalSizeInUsd;
        uint256 totalCollateralInUsd;
        uint256 avgPrice;
    }

    mapping(address => mapping(uint256 => uint256)) public traderBalances; // userAddress => assetId => Balance
    mapping(address => uint256) public traderFilledOrderCounts; // userAddress => orderCount
    mapping(address => uint256) public traderOrderRequestCounts; // userAddress => orderRequestCount (limit order)

    mapping(address => mapping(uint256 => FilledOrder)) public filledOrders; // userAddress => traderOrderCount => Order (filled orders by trader)
    mapping(address => mapping(uint256 => OrderRequest)) public pendingOrders; // userAddress => traderOrderRequestCounts => Order (pending orders by trader)

    mapping(uint256 => mapping(uint256 => mapping(uint256 => OrderRequest)))
        public buyOrderBook; // indexAssetId => price => queue index => OrderRequest (Global Queue)
    mapping(uint256 => mapping(uint256 => mapping(uint256 => OrderRequest)))
        public sellOrderBook; // indexAssetId => price => queue index => OrderRequest (Global Queue)

    mapping(uint256 => uint256) public maxBidPrice; // indexAssetId => price
    mapping(uint256 => uint256) public minAskPrice; // indexAssetId => price

    mapping(uint256 => mapping(uint256 => uint256))
        public orderSizeInUsdForPriceTick; // indexAssetId => price => sum(sizeDeltaAbs) // TODO: 일단 USD 단위로 기록

    mapping(uint256 => uint256) public priceTickSizes; // indexAssetId => priceTickSize (in USD, 10^8 decimals)

    mapping(uint256 => uint256) public balancesTracker; // assetId => balance; only used in _depositInAmount
    mapping(uint256 => uint256) public tokenPoolAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public tokenReserveAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public maxLongCapacity; // assetId => tokenCount
    mapping(uint256 => uint256) public maxShortCapacity; // assetId => tokenCount // TODO: check - is it for stablecoins?

    mapping(bool => mapping(uint256 => GlobalPositionState))
        public globalPositionStates; // assetId => GlobalPositionState

    // TODO: open <> close 사이의 position을 하나로 연결하여 기록
    mapping(bytes32 => Position) public positions; // positionHash => Position

    // ------------------------------------------------- Constructor --------------------------------------------------

    constructor(address _priceManager) {
        priceManager = IPriceManager(_priceManager);
    }

    // -------------------------------------------------- Modifiers ---------------------------------------------------

    modifier onlyKeeper() {
        require(true, "only keeper"); // TODO: modify
        _;
    }

    // ------------------------------------------- Orderbook Queue Data Type ------------------------------------------
    mapping(uint256 => mapping(uint256 => uint256)) public buyFirstIndex; // indexAssetId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public buyLastIndex; // indexAssetId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public sellFirstIndex; // indexAssetId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public sellLastIndex; // indexAssetId => price => queue index

    // TODO: 맵핑 방식에서도 초기화 필요 (특정 자산Id, 인덱스에 처음 추가 시 초기화 필요)
    // uint256 buyFirst = 1;
    // uint256 buyLast = 0;
    // uint256 sellFirst = 1;
    // uint256 sellLast = 0;

    function enqueueOrderBook(OrderRequest memory request, bool isBuy) public {
        if (isBuy) {
            buyLastIndex[request.indexAssetId][request.limitPrice]++;
            uint256 buyLast = buyLastIndex[request.indexAssetId][
                request.limitPrice
            ];

            buyOrderBook[request.indexAssetId][request.limitPrice][
                buyLast
            ] = request;
        } else {
            sellLastIndex[request.indexAssetId][request.limitPrice]++;
            uint256 sellLast = sellLastIndex[request.indexAssetId][
                request.limitPrice
            ];
            sellOrderBook[request.indexAssetId][request.limitPrice][
                sellLast
            ] = request;
        }
    }

    function dequeueOrderBook(OrderRequest memory request, bool isBuy) public {
        if (isBuy) {
            uint256 buyLast = buyLastIndex[request.indexAssetId][
                request.limitPrice
            ];
            uint256 buyFirst = buyFirstIndex[request.indexAssetId][
                request.limitPrice
            ];
            require(buyLast > buyFirst, "L3Vault: buyOrderBook queue is empty");
            delete buyOrderBook[request.indexAssetId][request.limitPrice][
                buyFirst
            ];

            buyFirstIndex[request.indexAssetId][request.limitPrice]++;
        } else {
            uint256 sellLast = sellLastIndex[request.indexAssetId][
                request.limitPrice
            ];
            uint256 sellFirst = sellFirstIndex[request.indexAssetId][
                request.limitPrice
            ];
            require(
                sellLast > sellFirst,
                "L3Vault: sellOrderBook queue is empty"
            );
            delete sellOrderBook[request.indexAssetId][request.limitPrice][
                sellFirst
            ];

            sellFirstIndex[request.indexAssetId][request.limitPrice]++;
        }
    }

    // ------------------------------------------------ Util Functions ------------------------------------------------

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _abs(int x) private pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    function _getPositionKey(
        address _account,
        bool _isLong,
        uint256 _indexAssetId,
        uint256 _collateralAssetId
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _account,
                    _isLong,
                    _indexAssetId,
                    _collateralAssetId
                )
            );
    }

    function _getMarkPrice(
        uint256 _assetId,
        uint256 _size,
        bool _isLong
    ) internal returns (uint256) {
        /**
         * // TODO: impl
         * @dev Jae Yoon
         */
        return priceManager.getAverageExecutionPrice(_assetId, _size, _isLong);
    }

    // TODO: check - for short positions, should we use collateralAsset for tracking position size?
    function updateGlobalPositionState(
        bool _isLong,
        bool _isIncrease,
        uint256 _indexAssetId,
        uint256 _sizeDelta,
        uint256 _collateralDelta,
        uint256 _markPrice
    ) internal {
        globalPositionStates[_isLong][_indexAssetId]
            .avgPrice = _getNextAvgPrice(
            _isIncrease,
            globalPositionStates[_isLong][_indexAssetId].totalSizeInUsd,
            globalPositionStates[_isLong][_indexAssetId].avgPrice,
            _sizeDelta,
            _markPrice
        );

        if (_isIncrease) {
            globalPositionStates[_isLong][_indexAssetId]
                .totalSizeInUsd += _sizeDelta;
            globalPositionStates[_isLong][_indexAssetId]
                .totalCollateralInUsd += _collateralDelta;
        } else {
            globalPositionStates[_isLong][_indexAssetId]
                .totalSizeInUsd -= _sizeDelta;
            globalPositionStates[_isLong][_indexAssetId]
                .totalCollateralInUsd -= _collateralDelta;
        }
    }

    /**
     * (new avg price) * (new size) = (old avg price) * (old size) + (mark price) * (size delta)
     * */
    function _getNextAvgPrice(
        bool _isIncreaseInSize,
        uint256 _prevSizeInUsd,
        uint256 _prevAvgPrice,
        uint256 _sizeDeltaInUsd,
        uint256 _markPrice
    ) internal pure returns (uint256) {
        uint256 _prevSizeInTokens = (_prevSizeInUsd / _prevAvgPrice);
        uint256 _sizeDeltaInTokens = (_sizeDeltaInUsd / _markPrice);

        if (_isIncreaseInSize) {
            uint256 newSize = _prevSizeInTokens + _sizeDeltaInTokens;
            uint256 nextAvgPrice = newSize == 0
                ? 0
                : (_prevAvgPrice *
                    _prevSizeInTokens +
                    _markPrice *
                    _sizeDeltaInTokens) / newSize;
            return nextAvgPrice;
        } else {
            // TODO: check - this logic needed?
            uint256 newSize = _prevSizeInTokens - _sizeDeltaInTokens;
            uint256 nextAvgPrice = newSize == 0
                ? 0
                : (_prevAvgPrice *
                    _prevSizeInTokens -
                    _markPrice *
                    _sizeDeltaInTokens) / newSize;
            return nextAvgPrice;
        }
    }

    function _usdToToken(
        uint256 _usdAmount,
        uint256 _tokenPrice,
        uint256 _tokenDecimals
    ) internal pure returns (uint256) {
        return
            ((_usdAmount * 10 ** _tokenDecimals) / 10 ** usdDecimals) /
            _tokenPrice;
    }

    function _tokenToUsd(
        uint256 _tokenAmount,
        uint256 _tokenPrice,
        uint256 _tokenDecimals
    ) internal pure returns (uint256) {
        return
            ((_tokenAmount * _tokenPrice) * 10 ** usdDecimals) /
            10 ** _tokenDecimals;
    }

    function _calculatePnL(
        uint256 _size,
        uint256 _averagePrice,
        uint256 _markPrice,
        bool _isLong
    ) internal pure returns (uint256, bool) {
        uint256 pnlAbs = _markPrice >= _averagePrice
            ? (_size * (_markPrice - _averagePrice)) / 10 ** 18
            : (_size * (_averagePrice - _markPrice)) / 10 ** 18;
        bool hasProfit = _markPrice >= _averagePrice ? _isLong : !_isLong;
        return (pnlAbs, hasProfit);
    }

    // ---------------------------------------------- Primary Functions -----------------------------------------------

    // function _increasePoolAmounts(uint256 assetId, uint256 _amount) internal {
    //     tokenPoolAmounts[assetId] += _amount;
    // }

    // function _decreasePoolAmounts(uint256 assetId, uint256 _amount) internal {
    //     require(
    //         tokenPoolAmounts[assetId] >= _amount,
    //         "L3Vault: Not enough token pool _amount"
    //     );
    //     tokenPoolAmounts[assetId] -= _amount;
    // }

    function _increaseReserveAmounts(
        uint256 assetId,
        uint256 _amount
    ) internal {
        require(
            tokenPoolAmounts[assetId] >= tokenReserveAmounts[assetId] + _amount,
            "L3Vault: Not enough token pool amount"
        );
        tokenReserveAmounts[assetId] += _amount;
    }

    function _decreaseReserveAmounts(
        uint256 assetId,
        uint256 _amount
    ) internal {
        require(
            tokenReserveAmounts[assetId] >= _amount,
            "L3Vault: Not enough token reserve amount"
        );
        tokenReserveAmounts[assetId] -= _amount;
    }

    function updatePosition(
        Position storage _position,
        uint256 _markPrice,
        uint256 _sizeDeltaAbsInUsd,
        uint256 _collateralDeltaAbsInUsd,
        bool _isIncreaseInSize,
        bool _isIncreaseInCollateral
    ) internal {
        if (_sizeDeltaAbsInUsd > 0 && _isIncreaseInSize) {
            _position.avgOpenPrice = _getNextAvgPrice(
                _isIncreaseInSize,
                _position.sizeInUsd,
                _position.avgOpenPrice,
                _sizeDeltaAbsInUsd,
                _markPrice
            );
        }
        _position.sizeInUsd = _isIncreaseInSize
            ? _position.sizeInUsd + _sizeDeltaAbsInUsd
            : _position.sizeInUsd - _sizeDeltaAbsInUsd;

        _position.collateralInUsd = _isIncreaseInCollateral
            ? _position.collateralInUsd + _collateralDeltaAbsInUsd
            : _position.collateralInUsd - _collateralDeltaAbsInUsd;

        _position.lastUpdatedTime = block.timestamp;
    }

    function settlePnL(
        Position memory _position,
        bool _isLong,
        uint256 _markPrice,
        uint256 _indexAssetId,
        uint256 _collateralAssetId,
        uint256 _sizeAbsInUsd,
        uint256 _collateralAbsInUsd
    ) internal {
        (uint256 pnlUsdAbs, bool traderHasProfit) = _calculatePnL(
            _position.sizeInUsd,
            _position.avgOpenPrice,
            _markPrice,
            _isLong
        );

        traderBalances[msg.sender][_collateralAssetId] += _collateralAbsInUsd;
        traderBalances[msg.sender][_collateralAssetId] = traderHasProfit
            ? traderBalances[msg.sender][_collateralAssetId] + pnlUsdAbs
            : traderBalances[msg.sender][_collateralAssetId] - pnlUsdAbs;
        // TODO: check - PnL includes collateral?

        tokenPoolAmounts[USD_ID] = traderHasProfit // TODO: check- settlement in USD or in tokens?
            ? tokenPoolAmounts[USD_ID] - pnlUsdAbs
            : tokenPoolAmounts[USD_ID] + pnlUsdAbs;

        tokenReserveAmounts[_indexAssetId] -= _sizeAbsInUsd;
    }

    // --------------------------------------------- Validation Functions ---------------------------------------------

    function _isAssetIdValid(uint256 _assetId) internal pure returns (bool) {
        // TODO: deal with delisting assets
        return _assetId < assetIdCounter;
    }

    function _validateOrder(OrderContext calldata c) internal view {
        require(msg.sender != address(0), "L3Vault: Invalid sender address");
        require(
            msg.sender == tx.origin,
            "L3Vault: Invalid sender address (contract)"
        );
        require(
            _isAssetIdValid(c._indexAssetId),
            "L3Vault: Invalid index asset id"
        );
        require(
            traderBalances[msg.sender][c._collateralAssetId] >=
                c._collateralAbsInUsd,
            "L3Vault: Not enough balance"
        );
        require(c._sizeAbsInUsd >= 0, "L3Vault: Invalid size");
        require(c._collateralAbsInUsd >= 0, "L3Vault: Invalid collateral size");
    }

    function _validateIncreaseExecution(OrderContext calldata c) internal view {
        require(
            tokenPoolAmounts[c._indexAssetId] >=
                tokenReserveAmounts[c._indexAssetId] + c._sizeAbsInUsd,
            "L3Vault: Not enough token pool amount"
        );
        if (c._isLong) {
            require(
                maxLongCapacity[c._indexAssetId] >=
                    globalPositionStates[true][c._indexAssetId].totalSizeInUsd +
                        c._sizeAbsInUsd,
                "L3Vault: Exceeds max long capacity"
            );
        } else {
            require(
                maxShortCapacity[c._indexAssetId] >=
                    globalPositionStates[false][c._indexAssetId]
                        .totalSizeInUsd +
                        c._sizeAbsInUsd,
                "L3Vault: Exceeds max short capacity"
            );
        }
    }

    function _validateDecreaseExecution(
        OrderContext calldata c,
        bytes32 _key,
        uint256 _markPrice
    ) internal view {
        require(
            positions[_key].sizeInUsd >= c._sizeAbsInUsd,
            "L3Vault: Not enough position size"
        );
        require(
            positions[_key].collateralInUsd >=
                _tokenToUsd(
                    c._collateralAbsInUsd,
                    _markPrice,
                    tokenDecimals[c._collateralAssetId]
                ),
            "L3Vault: Not enough collateral size"
        );
    }

    // ----------------------------------------------------------------------------------------------------------------
    // ----------------------------------------------- Order Functions ------------------------------------------------
    // ----------------------------------------------------------------------------------------------------------------

    function increaseCollateral() external {
        // call when sizeDelta = 0 (leverage down)
    }

    function decreaseCollateral() external {
        // call when sizeDelta = 0 (leverage up)
    }

    function placeLimitOrder(OrderContext calldata c) external {
        // FIXME: orderSizeForPriceTick 업데이트

        _validateOrder(c);

        OrderRequest memory orderRequest = OrderRequest(
            msg.sender,
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._collateralAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            c._limitPrice
        );

        pendingOrders[msg.sender][
            traderOrderRequestCounts[msg.sender]
        ] = orderRequest;
        traderOrderRequestCounts[msg.sender]++;

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
        enqueueOrderBook(orderRequest, _isBuy); // TODO: check - limit price should have validations for tick sizes
    }

    function cancleLimitOrder() public {}

    function updateLimitOrder() public {}

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
    function executeLimitOrdersAndGetPriceImpact(
        bool _isBuy,
        uint256 _indexAssetId,
        uint256 _currentMarkPrice
    ) external onlyKeeper returns (uint256) {
        // FIXME: 주문 체결 후 호가 창 빌 때마다 maxBidPrice, minAskPrice 업데이트

        uint256 _interimMarkPrice = _currentMarkPrice; // initialize

        // uint256 _limitPriceIterator = maxBidPrice[_indexAssetId]; // intialize

        uint256 _limitPriceIterator = _isBuy
            ? maxBidPrice[_indexAssetId]
            : minAskPrice[_indexAssetId]; // intialize

        bool loopCondition = _isBuy
            ? _limitPriceIterator >= _interimMarkPrice
            : _limitPriceIterator < _interimMarkPrice;

        // TODO: maxBidPrice에 이상치가 있을 경우 처리
        // check - for the case the two values are equal?
        while (loopCondition) {
            // check amounts of orders that can be filled in this price tick
            // if `_sizeCap` amount of orders are filled, the mark price will reach `_limitPriceIterator`.
            // i.e. _interimMarkPrice + (price buffer) => _limitPriceIterator

            // then, the max amount of orders that can be filled in this price tick iteration is
            // min(sizeCap, orderSizeForPriceTick[_indexAssetId][_limitPriceIterator])

            // PBC = PRICE_BUFFER_CHANGE_CONSTANT
            // _interimMarkPrice * PBC * (sizeCap) = (price shift) = (_limitPriceIterator - _interimMarkPrice)

            if (
                orderSizeInUsdForPriceTick[_indexAssetId][
                    _limitPriceIterator
                ] == 0
            ) {
                // no order to execute for this limit price tick

                _limitPriceIterator = _isBuy
                    ? _limitPriceIterator + priceTickSizes[_indexAssetId]
                    : _limitPriceIterator - priceTickSizes[_indexAssetId]; // decrease for buy
                continue;
            }

            // _sizeCap = 이번 limit price tick에서 체결할 수 있는 최대 주문량
            // i.e. price impact가 발생하여 interimMarkPrice가 limitPriceIterator에 도달하는 경우
            // 하나의 price tick 안의 다 requests를 처리하고나면 _sizeCap -= orderSizeInUsdForPriceTick[_indexAssetId][_limitPriceIterator]

            // note: this is the right place for the variable `_sizeCap` declaration
            // `_sizeCap` maintains its context within the while loop
            uint256 _sizeCap = _abs(
                int256(_limitPriceIterator) - int256(_interimMarkPrice)
            ) / (_interimMarkPrice * uint256(PRICE_BUFFER_CHANGE_CONSTANT)); // TODO: decimals 확인

            bool isPartialForThePriceTick = _sizeCap <
                orderSizeInUsdForPriceTick[_indexAssetId][_limitPriceIterator];

            uint256 _fillAmount = isPartialForThePriceTick
                ? _sizeCap // _sizeCap 남아있는만큼 체결하고 종료
                : orderSizeInUsdForPriceTick[_indexAssetId][
                    _limitPriceIterator
                ]; // _fillAmount = 이번 price tick에서 체결할 주문량

            // 이번 price tick에서 발생할 price impact
            uint256 _priceImpactInUsd = _interimMarkPrice *
                uint256(PRICE_BUFFER_CHANGE_CONSTANT) *
                _fillAmount;

            uint256 avgExecutionPrice = _getAvgExecutionPrice(
                _interimMarkPrice,
                _priceImpactInUsd,
                _isBuy
            );

            // _orderRequest[i].sizeAbs > _sizeCap => isPartial = true

            mapping(uint256 => OrderRequest) storage _orderRequests = _isBuy
                ? buyOrderBook[_indexAssetId][_limitPriceIterator]
                : sellOrderBook[_indexAssetId][_limitPriceIterator];

            uint256 firstIdx = _isBuy
                ? buyFirstIndex[_indexAssetId][_limitPriceIterator]
                : sellFirstIndex[_indexAssetId][_limitPriceIterator];

            uint256 lastIdx = _isBuy
                ? buyLastIndex[_indexAssetId][_limitPriceIterator]
                : sellLastIndex[_indexAssetId][_limitPriceIterator];

            for (uint256 i = firstIdx; i <= lastIdx; i++) {
                // TODO: pendingOrders에서 제거 - 필요한 기능인지 점검
                // TODO: validateExecution here (increase, decrease)

                OrderRequest memory request = _orderRequests[i];

                _fillLimitOrder(request, avgExecutionPrice, _sizeCap, _isBuy);

                if (_sizeCap == 0) {
                    break;
                }
            }

            _interimMarkPrice = _isBuy
                ? _interimMarkPrice + _priceImpactInUsd
                : _interimMarkPrice - _priceImpactInUsd; // 이번 price tick 주문 iteration 이후 Price Impact를 interimPrice에 적용

            // _sizeCap -= orderSizeInUsdForPriceTick[_indexAssetId][
            //     _limitPriceIterator
            // ];
            _limitPriceIterator = _isBuy
                ? _limitPriceIterator - priceTickSizes[_indexAssetId]
                : _limitPriceIterator + priceTickSizes[_indexAssetId]; // next iteration; decrease for buy

            // update while loop condition for the next iteration
            loopCondition = _isBuy
                ? _limitPriceIterator >= _interimMarkPrice
                : _limitPriceIterator < _interimMarkPrice;

            if (isPartialForThePriceTick) {
                break;
            }
            // Note: if `isPartial = true` in this while loop,  _sizeCap will be 0 after the for loop
        }
        return _interimMarkPrice;
    }

    function _fillLimitOrder(
        OrderRequest memory _request,
        uint256 _avgExecutionPrice,
        uint256 _sizeCap,
        bool _isBuy // bool _isPartial
    ) private {
        bool _isPartial = _request.sizeAbsInUsd > _sizeCap;
        uint256 partialRatio = _isPartial
            ? (_sizeCap / _request.sizeAbsInUsd) * 10 ** 8 // TODO: - set decimals as a constant
            : 1 * 10 ** 8;
        // uint256 _sizeAbsInUsd = _isPartial
        //     ? _request.sizeAbsInUsd - _sizeCap
        //     : _request.sizeAbsInUsd;

        uint256 _sizeAbsInUsd = _isPartial ? _sizeCap : _request.sizeAbsInUsd;

        uint256 _collateralAbsInUsd = _isPartial
            ? (_request.collateralAbsInUsd * partialRatio) / 10 ** 8
            : _request.collateralAbsInUsd;

        filledOrders[_request.trader][
            traderFilledOrderCounts[_request.trader]
        ] = FilledOrder(
            false,
            _request.isLong,
            _request.isIncrease,
            _request.indexAssetId,
            _request.collateralAssetId,
            _sizeAbsInUsd,
            _collateralAbsInUsd,
            _avgExecutionPrice
        );
        traderFilledOrderCounts[_request.trader] += 1;

        // update position
        bytes32 key = _getPositionKey(
            _request.trader,
            _request.isLong,
            _request.indexAssetId,
            _request.collateralAssetId
        );
        // Position {size, collateralSizeInUsd, avgOpenPrice, lastUpdatedTime}
        if (_request.isIncrease) {
            Position storage position = positions[key];

            updatePosition(
                position,
                _avgExecutionPrice,
                _sizeAbsInUsd,
                _collateralAbsInUsd,
                true, // isIncreaseInSize
                true // isIncreaseInCollateral
            );
        } else {
            // position 업데이트
            // PnL 계산, trader balance, poolAmounts, reservedAmounts 업데이트
            // position 삭제 검사
            Position storage position = positions[key];

            settlePnL(
                position,
                _request.isLong,
                _avgExecutionPrice,
                _request.indexAssetId,
                _request.collateralAssetId,
                _sizeAbsInUsd,
                _collateralAbsInUsd
            );

            if (_sizeAbsInUsd == position.sizeInUsd) {
                delete positions[key];
            } else {
                updatePosition(
                    position,
                    _avgExecutionPrice,
                    _sizeAbsInUsd,
                    _collateralAbsInUsd,
                    false,
                    false
                );
            }
        }

        updateGlobalPositionState(
            _request.isLong,
            _request.isIncrease,
            _request.indexAssetId,
            _sizeAbsInUsd,
            _collateralAbsInUsd,
            _avgExecutionPrice
        );

        _sizeCap -= _sizeAbsInUsd; // TODO: validation - assert(sum(request.sizeAbs) == orderSizeInUsdForPriceTick[_indexAssetId][_limitPriceIterator])

        // delete or update (isPartial) limit order
        if (_isPartial) {
            _request.sizeAbsInUsd -= _sizeAbsInUsd;
            _request.collateralAbsInUsd -= _collateralAbsInUsd;
        } else {
            dequeueOrderBook(_request, _isBuy); // TODO: check - if the target order is the first one in the queue
        }
    }

    function _getAvgExecutionPrice(
        uint256 _basePrice,
        uint256 _priceImpactInUsd,
        bool _isIncrease
    ) internal pure returns (uint256) {
        return
            _isIncrease
                ? _basePrice + (_priceImpactInUsd / 2)
                : _basePrice - (_priceImpactInUsd / 2);
    }

    function placeMarketOrder(
        OrderContext calldata c
    ) external returns (bytes32) {
        _validateOrder(c);

        bytes32 key = _getPositionKey(
            msg.sender,
            c._isLong,
            c._indexAssetId,
            c._collateralAssetId
        );

        // get markprice
        bool _isBuy = c._isLong == c._isIncrease;
        uint256 markPrice = _getMarkPrice(
            c._indexAssetId,
            c._sizeAbsInUsd,
            _isBuy
        ); // TODO: check - to put after validations?

        if (c._isIncrease) {
            increasePosition(c, key, markPrice);
        } else {
            decreasePosition(c, key, markPrice);
        }

        return key;
    }

    function increasePosition(
        OrderContext calldata c,
        bytes32 _key,
        uint256 _markPrice // TODO: change name into executionPrice? => Price Impact 적용된 상태?
    ) internal {
        // validation
        _validateIncreaseExecution(c);

        // update state variables
        traderBalances[msg.sender][c._collateralAssetId] -= c
            ._collateralAbsInUsd;
        tokenReserveAmounts[c._indexAssetId] += c._sizeAbsInUsd;

        // fill the order
        filledOrders[msg.sender][
            traderFilledOrderCounts[msg.sender]
        ] = FilledOrder(
            true,
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._collateralAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            _markPrice
        );
        traderFilledOrderCounts[msg.sender] += 1;

        // update position
        Position storage position = positions[_key];

        updatePosition(
            position,
            _markPrice,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            true, // isIncreaseInSize
            true // isIncreaseInCollateral
        );

        // update global position state
        updateGlobalPositionState(
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            _markPrice
        );
    }

    function decreasePosition(
        OrderContext calldata c,
        bytes32 _key,
        uint256 _markPrice
    ) internal {
        // validation
        _validateDecreaseExecution(c, _key, _markPrice);

        // update state variables
        Position storage position = positions[_key];

        settlePnL(
            position,
            c._isLong,
            _markPrice,
            c._indexAssetId,
            c._collateralAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd
        );

        // fill the order
        filledOrders[msg.sender][
            traderFilledOrderCounts[msg.sender]
        ] = FilledOrder(
            c._isLong,
            c._isIncrease,
            true,
            c._indexAssetId,
            c._collateralAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            _markPrice
        );
        traderFilledOrderCounts[msg.sender] += 1;

        if (c._sizeAbsInUsd == position.sizeInUsd) {
            // close position
            delete positions[_key];
        } else {
            // partial close position

            updatePosition(
                position,
                _markPrice,
                c._sizeAbsInUsd,
                c._collateralAbsInUsd,
                false, // isIncreaseInSize
                false // isIncreaseInCollateral
            );
        }

        // update global position state
        updateGlobalPositionState(
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            _markPrice
        );
    }

    // ----------------------------------------- Deposit & Withdraw Functions -----------------------------------------
    // ------------------------------------------- Liquidity Pool Functions -------------------------------------------
    function addLiquidity(uint256 assetId, uint256 amount) external payable {
        require(msg.value >= amount, "L3Vault: insufficient amount");
        // TODO: check - how to mint the LP token?
        tokenPoolAmounts[assetId] += amount;
        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        } // refund
    }

    function removeLiquidity(uint256 assetId, uint256 amount) external {
        tokenPoolAmounts[assetId] -= amount;
        payable(msg.sender).transfer(amount);
    }
    // ---------------------------------------------------- Events ----------------------------------------------------
}
