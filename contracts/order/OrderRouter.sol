// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/Context.sol";
import "../interfaces/l3/IPriceManager.sol";
import "../interfaces/l3/ITraderVault.sol"; // TODO: change to Interface
import "../interfaces/l3/IOrderBook.sol";
import "../account/TraderVault.sol";
import "../global/GlobalState.sol";
import "./OrderValidator.sol";
import "../orderbook/OrderBook.sol";
import "../oracle/PriceManager.sol";
import "./OrderHistory.sol";
import "../position/PositionVault.sol";

// TODO: check - OrderRouter to inherit TraderVault?
contract OrderRouter is Context {
    TraderVault traderVault;
    OrderBook orderBook;
    PriceManager priceManager;
    GlobalState globalState;
    RisePool risePool;
    OrderValidator orderValidator;
    OrderHistory orderHistory;
    PositionVault positionVault;

    constructor(
        address _traderVault,
        address _orderBook,
        address _priceManager
    ) {
        traderVault = TraderVault(_traderVault);
        orderBook = OrderBook(_orderBook);
        priceManager = PriceManager(_priceManager);
    }

    function getMarkPrice(
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

    function _validateOrder(OrderContext calldata c) internal view {
        require(
            msg.sender != address(0),
            "OrderRouter: Invalid sender address"
        );
        require(
            msg.sender == tx.origin,
            "OrderRouter: Invalid sender address (contract)"
        );
        require(
            risePool.isAssetIdValid(c._indexAssetId),
            "OrderRouter: Invalid index asset id"
        );
        require(
            traderVault.getTraderBalance(msg.sender, c._marginAssetId) >=
                c._marginAbsInUsd,
            "OrderRouter: Not enough balance"
        );
        require(c._sizeAbsInUsd >= 0, "OrderRouter: Invalid size");
        require(c._marginAbsInUsd >= 0, "OrderRouter: Invalid margin size");
    }

    function increaseMargin() external {
        // call when sizeDelta = 0 (leverage down)
    }

    function decreaseMargin() external {
        // call when sizeDelta = 0 (leverage up)
    }

    function placeLimitOrder(OrderContext calldata c) external {
        _validateOrder(c);
        orderBook.placeLimitOrder(c);
    }

    function cancelLimitOrder() public {}

    function updateLimitOrder() public {}

    function placeMarketOrder(
        OrderContext calldata c
    ) external returns (bytes32) {
        _validateOrder(c);

        return executeMarketOrder(c);
    }

    function executeMarketOrder(
        OrderContext calldata c
    ) private returns (bytes32) {
        // TODO: settlePnL
        bool isBuy = c._isLong == c._isIncrease;

        uint256 markPrice = getMarkPrice(
            c._indexAssetId,
            c._sizeAbsInUsd,
            isBuy
        );

        bytes32 key = _getPositionKey(
            msg.sender,
            c._isLong,
            c._indexAssetId,
            c._marginAssetId
        );

        // validations
        c._isIncrease
            ? orderValidator.validateIncreaseExecution(c)
            : orderValidator.validateDecreaseExecution(c, key, markPrice);

        // update state variables
        if (c._isIncrease) {
            traderVault.decreaseTraderBalance(
                msg.sender,
                c._marginAssetId,
                c._marginAbsInUsd
            );
            risePool.increaseReserveAmounts(
                c._marginAssetId,
                c._marginAbsInUsd
            );
        }

        // fill the order
        orderHistory.fillOrder(
            msg.sender,
            true, // isMarketOrder
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._marginAssetId,
            c._sizeAbsInUsd,
            c._marginAbsInUsd,
            markPrice
        );

        uint256 positionSizeInUsd = positionVault.getPositionSizeInUsd(key);

        if (!c._isIncrease && c._sizeAbsInUsd == positionSizeInUsd) {
            // close position
            positionVault.deletePosition(key);
        } else {
            // partial close position
            positionVault.updatePosition(
                key,
                markPrice,
                c._sizeAbsInUsd,
                c._marginAbsInUsd,
                c._isIncrease, // isIncreaseInSize
                c._isIncrease // isIncreaseInMargin
            );
        }

        // update global position state
        globalState.updateGlobalPositionState(
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._sizeAbsInUsd,
            c._marginAbsInUsd,
            markPrice
        );

        return key;
    }
}
