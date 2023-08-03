// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../orderbook/OrderBook.sol";
import "./MarketOrder.sol";

contract OrderRouter {
    MarketOrder marketOrder;
    OrderBook orderBook;

    constructor(address _marketOrder, address _orderBook) {
        marketOrder = MarketOrder(_marketOrder);
        orderBook = OrderBook(_orderBook);
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

        return marketOrder.executeMarketOrder(c);
    }
}
