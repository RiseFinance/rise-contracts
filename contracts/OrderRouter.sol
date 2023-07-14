// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./CommonContext.sol";
import "./L3Vault.sol"; // TODO: change to Interface
import "./OrderBook.sol";

contract OrderRouter is CommonContext {
    L3Vault l3Vault;
    OrderBook orderBook;

    constructor(address _l3Vault, address _orderBook) {
        l3Vault = L3Vault(_l3Vault);
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
        require(
            l3Vault.isAssetIdValid(c._indexAssetId),
            "OrderRouter: Invalid index asset id"
        );
        require(
            l3Vault.getTraderBalance(msg.sender, c._collateralAssetId) >=
                c._collateralAbsInUsd,
            "OrderRouter: Not enough balance"
        );
        require(c._sizeAbsInUsd >= 0, "OrderRouter: Invalid size");
        require(
            c._collateralAbsInUsd >= 0,
            "OrderRouter: Invalid collateral size"
        );
    }

    function placeMarketOrder(
        OrderContext calldata c
    ) external returns (bytes32) {
        _validateOrder(c);

        // get markprice
        bool isBuy = c._isLong == c._isIncrease;

        if (c._isIncrease) {
            return l3Vault.increasePosition(c, isBuy);
        } else {
            return l3Vault.decreasePosition(c, isBuy);
        }
    }

    function placeLimitOrder(OrderContext calldata c) external {
        _validateOrder(c);
        orderBook.placeLimitOrder(c);
    }

    function cancleLimitOrder() public {}

    function updateLimitOrder() public {}

    function increaseCollateral() external {
        // call when sizeDelta = 0 (leverage down)
    }

    function decreaseCollateral() external {
        // call when sizeDelta = 0 (leverage up)
    }
}
