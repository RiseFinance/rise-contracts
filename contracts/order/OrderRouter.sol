// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../account/TraderVault.sol";
import "../global/GlobalState.sol";
import "./OrderValidator.sol";
import "../orderbook/OrderBook.sol";
import "../oracle/PriceManager.sol";
import "./OrderHistory.sol";
import "./OrderUtils.sol";
import "../position/PositionVault.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";

contract OrderRouter is OrderUtils {
    OrderValidator orderValidator;
    PriceManager priceManager;
    OrderHistory orderHistory;
    GlobalState globalState;
    OrderUtils orderUtils;
    OrderBook orderBook;

    struct FillMarketOrderContext {
        bool isBuy;
        bool isOpen;
        uint256 marginAssetId;
        uint256 avgExecPrice;
        bytes32 key;
    }

    constructor(
        address _traderVault,
        address _orderBook,
        address _priceManager
    ) {
        traderVault = TraderVault(_traderVault);
        orderBook = OrderBook(_orderBook);
        priceManager = PriceManager(_priceManager);
    }

    function _getAvgExecPriceAndUpdatePriceBuffer(
        uint256 _assetId,
        uint256 _size,
        bool _isLong
    ) internal returns (uint256) {
        /**
         * // TODO: impl
         * @dev Jae Yoon
         */
        return
            priceManager.getAvgExecPriceAndUpdatePriceBuffer(
                _assetId,
                _size,
                _isLong
            );
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
        // require(
        //     risePool.isMarketIdValid(c._marketId),
        //     "OrderRouter: Invalid index asset id"
        // );
        // require(
        //     traderVault.getTraderBalance(msg.sender, c._marginAssetId) >=
        //         c._marginAbsInUsd,
        //     "OrderRouter: Not enough balance"
        // );
        require(c._sizeAbs >= 0, "OrderRouter: Invalid size");
        require(c._marginAbs >= 0, "OrderRouter: Invalid margin size");
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
        FillMarketOrderContext memory fmc;

        fmc.marginAssetId = market.getMarketInfo(c._marketId).marginAssetId;
        fmc.isBuy = c._isLong == c._isIncrease;

        fmc.avgExecPrice = _getAvgExecPriceAndUpdatePriceBuffer(
            c._marketId,
            c._sizeAbs,
            fmc.isBuy
        );

        fmc.key = _getPositionKey(msg.sender, c._isLong, c._marketId);

        // validations
        c._isIncrease
            ? orderValidator.validateIncreaseExecution(c)
            : orderValidator.validateDecreaseExecution(c, fmc.key);

        // update state variables
        if (c._isIncrease) {
            traderVault.decreaseTraderBalance(
                msg.sender,
                fmc.marginAssetId,
                c._marginAbs
            );
            c._isLong
                ? risePool.increaseLongReserveAmount(
                    fmc.marginAssetId,
                    c._sizeAbs
                )
                : risePool.increaseShortReserveAmount(
                    fmc.marginAssetId,
                    c._sizeAbs
                );
        } else {
            // PnL settlement
            orderUtils.settlePnL(
                fmc.key,
                c._isLong,
                fmc.avgExecPrice,
                c._marketId,
                c._sizeAbs,
                c._marginAbs
            );
        }

        // fill the order
        orderHistory.recordOrder(
            msg.sender,
            true, // isMarketOrder
            c._isLong,
            c._isIncrease,
            c._marketId,
            c._sizeAbs,
            c._marginAbs,
            fmc.avgExecPrice
        );

        uint256 positionSize = positionVault.getPositionSize(fmc.key);

        if (!c._isIncrease && c._sizeAbs == positionSize) {
            // close position
            positionVault.deletePosition(fmc.key);
        } else {
            // partial close position
            positionVault.updatePosition(
                fmc.key,
                positionSize == 0, // isOpen
                msg.sender, // trader
                c._isLong,
                c._marketId,
                fmc.avgExecPrice,
                c._sizeAbs,
                c._marginAbs,
                c._isIncrease, // isIncreaseInSize
                c._isIncrease // isIncreaseInMargin
            );
        }

        // update global position state

        if (c._isLong) {
            globalState.updateGlobalLongPositionState(
                c._isIncrease,
                c._marketId,
                c._sizeAbs,
                c._marginAbs,
                fmc.avgExecPrice
            );
        } else {
            globalState.updateGlobalShortPositionState(
                c._isIncrease,
                c._marketId,
                c._sizeAbs,
                c._marginAbs,
                fmc.avgExecPrice
            );
        }

        return fmc.key;
    }
}
