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

    function _validateOrder(OrderRequest calldata req) internal view {
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
        require(req.sizeAbs >= 0, "OrderRouter: Invalid size");
        require(req.marginAbs >= 0, "OrderRouter: Invalid margin size");
    }

    function increaseMargin() external {
        // call when sizeDelta = 0 (leverage down)
    }

    function decreaseMargin() external {
        // call when sizeDelta = 0 (leverage up)
    }

    function adjustLeverage() external {}

    function placeLimitOrder(OrderRequest calldata req) external {
        _validateOrder(req);
        orderBook.placeLimitOrder(req);
    }

    function cancelLimitOrder() public {}

    function updateLimitOrder() public {}

    function placeMarketOrder(
        OrderRequest calldata req
    ) external returns (bytes32) {
        _validateOrder(req);

        return marketOrder.executeMarketOrder(req);
    }
}
