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
    int public constant DECAY_CONSTANT = (PRICE_BUFFER_PRECISION / 100) / 300;
    // 1% decay per 5 miniutes
    int public constant PRICE_BUFFER_CHANGE_CONSTANT =
        ((10 ** 6) * SIZE_PRECISION) / (PRICE_BUFFER_PRECISION / 100);
    // 1% price buffer per 10^6 USD

    uint256 public constant usdDecimals = 8;
    uint256 public constant USD_ID = 0;
    uint256 public constant ETH_ID = 1;
    uint256 private constant assetIdCounter = 1; // temporary
    mapping(uint256 => uint256) public tokenDecimals; // TODO: listing restriction needed

    struct OrderContext {
        uint256 _indexAssetId;
        uint256 _collateralAssetId;
        bool _isLong;
        bool _isIncrease;
        uint256 _size; // in token amounts
        uint256 _collateralSize; // in token amounts
        uint256 _limitPrice; // empty for market orders
    }

    struct OrderRequest {
        address trader;
        uint256 indexAssetId; // redundant?
        uint256 collateralAssetId;
        bool isLong;
        bool isIncrease;
        uint256 sizeAbs;
        uint256 collateralSizeAbs;
        uint256 limitPrice;
    }

    struct FilledOrder {
        uint256 indexAssetId;
        uint256 collateralAssetId;
        bool isLong;
        bool isIncrease;
        uint256 sizeDeltaAbs;
        uint256 collateralSizeDeltaAbs;
        bool isMarketOrder;
        uint256 executionPrice;
    }

    struct Position {
        uint256 size;
        uint256 collateralSizeInUsd;
        uint256 avgOpenPrice; // TODO: check - should be coupled w/ positions link logic
        uint256 lastUpdatedTime; // Currently not used for any validation
    }

    struct GlobalPositionState {
        uint256 totalSize;
        uint256 totalCollateral;
        uint256 avgPrice;
    }

    mapping(address => mapping(uint256 => uint256)) public traderBalances; // userAddress => assetId => Balance
    mapping(address => uint256) public traderFilledOrderCounts; // userAddress => orderCount
    mapping(address => uint256) public traderOrderRequestCounts; // userAddress => orderRequestCount (limit order)

    mapping(address => mapping(uint256 => FilledOrder)) public filledOrders; // userAddress => traderOrderCount => Order (filled orders by trader)
    mapping(address => mapping(uint256 => OrderRequest)) public pendingOrders; // userAddress => traderOrderRequestCounts => Order (pending orders by trader)

    mapping(uint256 => mapping(uint256 => OrderRequest[])) public buyOrderBook; // indexAssetId => price => Order[] (Global Queue)
    mapping(uint256 => mapping(uint256 => OrderRequest[])) public sellOrderBook; // indexAssetId => price => Order[] (Global Queue)

    mapping(uint256 => uint256) public maxBidPrice; // indexAssetId => price
    mapping(uint256 => uint256) public minAskPrice; // indexAssetId => price

    mapping(uint256 => mapping(uint256 => uint256))
        public orderSizeInUsdForPriceTick; // indexAssetID => price => sum(sizeDeltaAbs) // TODO: 일단 USD 단위로 기록

    mapping(uint256 => uint256) public priceTickSizes; // indexAssetId => priceTickSize (in USD, 10^8 decimals)

    mapping(uint256 => uint256) public balancesTracker; // assetId => balance; only used in _depositInAmount
    mapping(uint256 => uint256) public tokenPoolAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public tokenReserveAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public maxLongCapacity; // assetId => tokenCount
    mapping(uint256 => uint256) public maxShortCapacity; // assetId => tokenCount // TODO: check - is it for stablecoins?

    mapping(bool => mapping(uint256 => GlobalPositionState))
        public globalPositionState; // assetId => GlobalPositionState

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

    // ------------------------------------------------ Util Functions ------------------------------------------------

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
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
         *
         * @dev Jae Yoon
         */
        return priceManager.getAverageExecutionPrice(_assetId, _size, _isLong);
    }

    // TODO: check - for short positions, should we use collateralAsset for tracking position size?
    function _updateGlobalPositionState(
        bool _isLong,
        bool _isIncrease,
        uint256 _indexAssetId,
        uint256 _sizeDelta,
        uint256 _collateralDelta,
        uint256 _markPrice
    ) internal {
        globalPositionState[_isLong][_indexAssetId].avgPrice = _getNewAvgPrice(
            _isIncrease,
            globalPositionState[_isLong][_indexAssetId].totalSize,
            globalPositionState[_isLong][_indexAssetId].avgPrice,
            _sizeDelta,
            _markPrice
        );

        if (_isIncrease) {
            globalPositionState[_isLong][_indexAssetId].totalSize += _sizeDelta;
            globalPositionState[_isLong][_indexAssetId]
                .totalCollateral += _collateralDelta;
        } else {
            globalPositionState[_isLong][_indexAssetId].totalSize -= _sizeDelta;
            globalPositionState[_isLong][_indexAssetId]
                .totalCollateral -= _collateralDelta;
        }
    }

    /**
     * (new avg price) * (new size) = (old avg price) * (old size) + (mark price) * (size delta)
     * */
    function _getNewAvgPrice(
        bool _isIncrease,
        uint256 _oldSize,
        uint256 _oldAvgPrice,
        uint256 _sizeDelta,
        uint256 _markPrice
    ) internal pure returns (uint256) {
        if (_isIncrease) {
            uint256 newSize = _oldSize + _sizeDelta;
            uint256 newAvgPrice = newSize == 0
                ? 0
                : (_oldAvgPrice * _oldSize + _markPrice * _sizeDelta) / newSize;
            return newAvgPrice;
        } else {
            // TODO: check - this logic needed?
            uint256 newSize = _oldSize - _sizeDelta;
            uint256 newAvgPrice = newSize == 0
                ? 0
                : (_oldAvgPrice * _oldSize - _markPrice * _sizeDelta) / newSize;
            return newAvgPrice;
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
                c._collateralSize,
            "L3Vault: Not enough balance"
        );
        require(c._size >= 0, "L3Vault: Invalid size");
        require(c._collateralSize >= 0, "L3Vault: Invalid collateral size");
    }

    function _validateIncreaseExecution(OrderContext calldata c) internal view {
        require(
            tokenPoolAmounts[c._indexAssetId] >=
                tokenReserveAmounts[c._indexAssetId] + c._size,
            "L3Vault: Not enough token pool amount"
        );
        if (c._isLong) {
            require(
                maxLongCapacity[c._indexAssetId] >=
                    globalPositionState[true][c._indexAssetId].totalSize +
                        c._size,
                "L3Vault: Exceeds max long capacity"
            );
        } else {
            require(
                maxShortCapacity[c._indexAssetId] >=
                    globalPositionState[false][c._indexAssetId].totalSize +
                        c._size,
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
            positions[_key].size >= c._size,
            "L3Vault: Not enough position size"
        );
        require(
            positions[_key].collateralSizeInUsd >=
                _tokenToUsd(
                    c._collateralSize,
                    _markPrice,
                    tokenDecimals[c._collateralAssetId]
                ),
            "L3Vault: Not enough collateral size"
        );
    }

    // ----------------------------------------------- Order Functions ------------------------------------------------

    function placeLimitOrder(OrderContext calldata c) external {
        // FIXME: orderSizeForPriceTick 업데이트

        _validateOrder(c);

        OrderRequest memory orderRequest = OrderRequest(
            msg.sender,
            c._indexAssetId,
            c._collateralAssetId,
            c._isLong,
            c._isIncrease,
            c._size,
            c._collateralSize,
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
            buyOrderBook[c._indexAssetId][c._limitPrice].push(orderRequest); // TODO: check - limit price should have validations for tick sizes
        } else {
            if (
                c._limitPrice < minAskPrice[c._indexAssetId] ||
                minAskPrice[c._indexAssetId] == 0
            ) {
                minAskPrice[c._indexAssetId] = c._limitPrice;
            }
            sellOrderBook[c._indexAssetId][c._limitPrice].push(orderRequest);
        }
    }

    function removeLimitOrder() public {}

    function updateLimitOrder() public {}

    function executeLimitOrders(
        bool _isBuy,
        uint256 _indexAssetId,
        uint256 _currentMarkPrice
    ) external onlyKeeper {
        // TODO: 주문 체결 후 호가 창 빌 때마다 maxBidPrice, minAskPrice 업데이트
        // price tick 단위로 오더북을 순회하며 체결할 수 있는 오더를 우선순위대로 체결시키고
        // 종료된 후의 PriceBufferDelta값을 리턴하여
        // PriceManager 컨트랙트에서 업데이트할 수 있도록 한다.
        if (_isBuy) {
            uint256 _interimMarkPrice = _currentMarkPrice; // initialize
            uint256 _limitPriceIterator = maxBidPrice[_indexAssetId]; // intialize

            // TODO: maxBidPrice에 이상치가 있을 경우 처리

            // check - 같을 때에도 iteration 돌기?
            while (_interimMarkPrice < _limitPriceIterator) {
                // 이번 티커에서 체결할 수 있는 오더의 수량을 체크한다.
                // _interimMarkPrice에서 sizeCap만큼 주문을 체결하면 _interimMarkPrice + priceBuffer가 _limitPriceIterator까지 올라간다고 하면,
                // 이번 순회에서는 min(sizeCap, orderSizeForPriceTick[_indexAssetId][_limitPriceIterator])만큼 체결할 수 있다.

                // 체결할 수 있는 오더의 수량을 체크한다.
                // PBC = PRICE_BUFFER_CHANGE_CONSTANT = 사이즈 당 가격 변화량(%) 상수
                // _interimMarkPrice * PBC * (sizeCap) = (가격 delta) = (_limitPriceIterator - _interimMarkPrice)

                // sizecap = 이번 limitPriceIterator (가격 티커)에서 체결할 수 있는 오더의 최대 사이즈

                if (
                    orderSizeInUsdForPriceTick[_indexAssetId][
                        _limitPriceIterator
                    ] == 0
                ) {
                    // no order to execute for this price tick
                    break;
                }

                uint256 _sizeCap = (_limitPriceIterator - _interimMarkPrice) /
                    (_interimMarkPrice * uint256(PRICE_BUFFER_CHANGE_CONSTANT)); // TODO: decimals 확인

                // 이번 iteration에서 모든 오더를 체결할 수 없을 경우 (다음 price tick으로 넘어갈 필요 없음)
                if (
                    _sizeCap <
                    orderSizeInUsdForPriceTick[_indexAssetId][
                        _limitPriceIterator
                    ]
                ) {
                    // execute limit orders
                    // 우선순위대로 (앞에서부터) for문 돌며 가능한 수량만큼 avgExecutionPrice로 체결하고 종료
                    // 만약 하나의 Order가 일부만 체결될 수 있다면, 체결 후 해당 Order는 삭제하지 않고 업데이트

                    break;
                } else {
                    // 이번 price tick에 걸린 주문을 전부 체결한다.
                    // avg execution price 계산

                    uint256 _priceImpactInUsd = _interimMarkPrice *
                        uint256(PRICE_BUFFER_CHANGE_CONSTANT) *
                        orderSizeInUsdForPriceTick[_indexAssetId][
                            _limitPriceIterator
                        ];

                    uint256 avgExecutionPrice = _getAvgExecutionPrice(
                        _interimMarkPrice,
                        _priceImpactInUsd,
                        true
                    );

                    OrderRequest[] memory _orderRequests = buyOrderBook[
                        _indexAssetId
                    ][_limitPriceIterator];

                    for (uint256 i = 0; i < _orderRequests.length; i++) {
                        // FIXME: _isIncrease 분기처리 필요
                        // FilledOrder 생성 및 filledOrders에 추가, traderFilledOrderCounts++
                        // position 업데이트
                        // orderbook에서 제거
                        // pendingOrders에서 제거
                        // TODO: 함수로 빼거나 increasePosition과 통합

                        // TODO: validateExecution here (increase, decrease)

                        OrderRequest memory request = _orderRequests[i];

                        // FilledOrder 생성 및 filledOrders에 추가
                        filledOrders[request.trader][
                            traderFilledOrderCounts[request.trader]
                        ] = FilledOrder(
                            request.indexAssetId,
                            request.collateralAssetId,
                            request.isLong,
                            request.isIncrease,
                            request.sizeAbs,
                            request.collateralSizeAbs,
                            false,
                            avgExecutionPrice
                        );
                        traderFilledOrderCounts[request.trader] += 1;

                        // update position
                        bytes32 key = _getPositionKey(
                            request.trader,
                            request.isLong,
                            request.indexAssetId,
                            request.collateralAssetId
                        );
                        // Position {size, collateralSizeInUsd, avgOpenPrice, lastUpdatedTime}
                        if (request.isIncrease) {
                            Position storage position = positions[key];
                            position.avgOpenPrice = _getNewAvgPrice(
                                request.isIncrease,
                                position.size,
                                position.avgOpenPrice,
                                request.sizeAbs,
                                avgExecutionPrice
                            );
                            position.size += request.sizeAbs;
                            position.collateralSizeInUsd += _tokenToUsd(
                                request.collateralSizeAbs,
                                avgExecutionPrice,
                                tokenDecimals[request.collateralAssetId]
                            );
                            position.lastUpdatedTime = block.timestamp;
                        } else {
                            // position 업데이트
                            // PnL 계산, trader balance, poolAmounts, reservedAmounts 업데이트
                            // position 삭제 검사
                            Position storage position = positions[key];
                            (
                                uint256 pnlUsdAbs,
                                bool isPositive
                            ) = _calculatePnL(
                                    position.size,
                                    position.avgOpenPrice,
                                    avgExecutionPrice,
                                    request.isLong
                                );

                            uint256 traderBalance = traderBalances[
                                request.trader
                            ][request.collateralAssetId];

                            traderBalance += request.collateralSizeAbs;
                            traderBalance = isPositive
                                ? traderBalance + pnlUsdAbs
                                : traderBalance - pnlUsdAbs;

                            tokenPoolAmounts[USD_ID] = isPositive
                                ? tokenPoolAmounts[USD_ID] - pnlUsdAbs
                                : tokenPoolAmounts[USD_ID] + pnlUsdAbs;

                            tokenReserveAmounts[request.indexAssetId] -= request
                                .sizeAbs;

                            if (request.sizeAbs == position.size) {
                                delete positions[key];
                            } else {
                                position.size -= request.sizeAbs;
                                position.collateralSizeInUsd -= _tokenToUsd(
                                    request.collateralSizeAbs,
                                    avgExecutionPrice,
                                    tokenDecimals[request.collateralAssetId]
                                );
                                position.lastUpdatedTime = block.timestamp;
                            }
                        }
                        _updateGlobalPositionState(
                            request.isLong,
                            request.isIncrease,
                            request.indexAssetId,
                            request.sizeAbs,
                            request.collateralSizeAbs,
                            avgExecutionPrice
                        );
                    }

                    _interimMarkPrice += _priceImpactInUsd; // 이번 price tick 주문 iteration 이후 Price Impact를 interimPrice에 적용
                }

                _limitPriceIterator -= priceTickSizes[_indexAssetId]; // decrease for buy
            }
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
        uint256 markPrice = _getMarkPrice(c._indexAssetId, c._size, _isBuy); // TODO: check - to put after validations?

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
        uint256 _markPrice // TODO: change name into executionPrice?
    ) internal {
        // validation
        _validateIncreaseExecution(c);

        // update state variables
        traderBalances[msg.sender][c._collateralAssetId] -= c._collateralSize;
        tokenReserveAmounts[c._indexAssetId] += c._size;

        // fill the order
        filledOrders[msg.sender][
            traderFilledOrderCounts[msg.sender]
        ] = FilledOrder(
            c._indexAssetId,
            c._collateralAssetId,
            c._isLong,
            c._isIncrease,
            c._size,
            c._collateralSize,
            true,
            _markPrice
        );
        traderFilledOrderCounts[msg.sender] += 1;

        // update position
        Position storage position = positions[_key];
        position.avgOpenPrice = _getNewAvgPrice(
            true,
            position.size,
            position.avgOpenPrice,
            c._size,
            _markPrice
        );
        position.size += c._size;
        position.collateralSizeInUsd += _tokenToUsd(
            c._collateralSize,
            _markPrice,
            tokenDecimals[c._collateralAssetId]
        );
        position.lastUpdatedTime = block.timestamp;

        // update global position state
        _updateGlobalPositionState(
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._size,
            c._collateralSize,
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
        (uint256 pnlUsdAbs, bool isPositive) = _calculatePnL(
            position.size,
            position.avgOpenPrice,
            _markPrice,
            c._isLong
        );

        uint256 traderBalance = traderBalances[msg.sender][
            c._collateralAssetId
        ];

        traderBalance += c._collateralSize; // c._collateralSize calculated before this point by the amount of decrease
        traderBalance = isPositive
            ? traderBalance + pnlUsdAbs // FIXME: USD or token?
            : traderBalance - pnlUsdAbs;
        // TODO: check - PnL includes collateral?

        // TODO: settlement in USD or tokens?
        tokenPoolAmounts[USD_ID] = isPositive
            ? tokenPoolAmounts[USD_ID] - pnlUsdAbs // add validation here for not going below 0 or allow & swap tokens => USD by system call
            : tokenPoolAmounts[USD_ID] + pnlUsdAbs;

        tokenReserveAmounts[c._indexAssetId] -= c._size;

        // fill the order
        filledOrders[msg.sender][
            traderFilledOrderCounts[msg.sender]
        ] = FilledOrder(
            c._indexAssetId,
            c._collateralAssetId,
            c._isLong,
            c._isIncrease,
            c._size,
            c._collateralSize,
            true,
            _markPrice
        );
        traderFilledOrderCounts[msg.sender] += 1;

        // update position
        // if close position
        if (c._size == position.size) {
            delete positions[_key];
        } else {
            // position.avgOpenPrice = _getNewAvgPrice(
            //     false,
            //     position.size,
            //     position.avgOpenPrice,
            //     c._size,
            //     _markPrice
            // );
            position.size -= c._size;
            position.collateralSizeInUsd -= _tokenToUsd(
                c._collateralSize,
                _markPrice,
                tokenDecimals[c._collateralAssetId]
            );
            position.lastUpdatedTime = block.timestamp;
        }

        // update global position state
        _updateGlobalPositionState(
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._size,
            c._collateralSize,
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
