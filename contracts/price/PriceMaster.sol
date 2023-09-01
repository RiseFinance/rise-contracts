// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "./PriceManager.sol";
import "../orderbook/OrderBook.sol";

contract PriceMaster {
    PriceManager public priceManager;
    OrderBook public orderBook;

    mapping(address => bool) public isPriceKeeper;

    modifier onlyPriceKeeper() {
        require(
            isPriceKeeper[msg.sender],
            "PriceManager: Should be called by keeper"
        );
        _;
    }

    constructor(
        address _priceManager,
        address _orderBook,
        address _keeperAddress
    ) {
        priceManager = PriceManager(_priceManager);
        orderBook = OrderBook(_orderBook);
        isPriceKeeper[_keeperAddress] = true;
    }

    function setPricesAndExecuteLimitOrders(
        uint256[] calldata _marketId,
        uint256[] calldata _price, // new index price from the data source
        bool _isInitialize
    ) public onlyPriceKeeper {
        require(_marketId.length == _price.length, "PriceMaster: Wrong input");
        uint256 l = _marketId.length;
        for (uint256 i = 0; i < l; i++) {
            priceManager.setPrice(_marketId[i], _price[i]);
            if (!_isInitialize) {
                bool checkBuyOrderBook = _price[i] <
                    priceManager.getIndexPrice(_marketId[i]);
                orderBook.executeLimitOrders(
                    checkBuyOrderBook, // isBuy
                    _marketId[i]
                );
            }
        }
    }
}
