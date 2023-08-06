// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";

import "hardhat/console.sol";

abstract contract OrderBookBase {
    mapping(address => uint256) public traderOrderRequestCounts; // userAddress => orderRequestCount (limit order)

    mapping(address => mapping(uint256 => OrderRequest)) public pendingOrders; // userAddress => traderOrderRequestCounts => Order (pending orders by trader)

    mapping(uint256 => mapping(uint256 => mapping(uint256 => OrderRequest)))
        internal buyOrderBook; // marketId => price => queue index => OrderRequest (Global Queue)
    mapping(uint256 => mapping(uint256 => mapping(uint256 => OrderRequest)))
        internal sellOrderBook; // marketId => price => queue index => OrderRequest (Global Queue)

    mapping(uint256 => uint256) public maxBidPrice; // marketId => price
    mapping(uint256 => uint256) public minAskPrice; // marketId => price

    mapping(uint256 => mapping(uint256 => uint256))
        public orderSizeForPriceTick; // marketId => price => sum(sizeDeltaAbs) / in Token Counts

    // ------------------------------------------- Orderbook Queue Data Type ------------------------------------------
    mapping(uint256 => mapping(uint256 => uint256)) public buyFirstIndex; // marketId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public buyLastIndex; // marketId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public sellFirstIndex; // marketId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public sellLastIndex; // marketId => price => queue index

    // FIXME: temporary
    function setMaxBidPrice(uint256 _marketId, uint256 _price) public {
        maxBidPrice[_marketId] = _price;
    }

    // FIXME: temporary
    function setMinAskPrice(uint256 _marketId, uint256 _price) public {
        minAskPrice[_marketId] = _price;
    }

    function enqueueOrderBook(OrderRequest memory req, bool _isBuy) public {
        if (_isBuy) {
            // If it is the first order added in the queue, set the first index to 1
            // for the last index, added below
            if (buyLastIndex[req.marketId][req.limitPrice] == 0) {
                buyFirstIndex[req.marketId][req.limitPrice] = 1;
            }

            uint256 buyLast = ++buyLastIndex[req.marketId][req.limitPrice];

            buyOrderBook[req.marketId][req.limitPrice][buyLast] = req;
        } else {
            // If it is the first order added in the queue, set the first index to 1
            // for the last index, added below
            if (sellLastIndex[req.marketId][req.limitPrice] == 0) {
                sellFirstIndex[req.marketId][req.limitPrice] = 1;
            }

            uint256 sellLast = ++sellLastIndex[req.marketId][req.limitPrice];
            sellOrderBook[req.marketId][req.limitPrice][sellLast] = req;
        }
        orderSizeForPriceTick[req.marketId][req.limitPrice] += req.sizeAbs;
    }

    function dequeueOrderBook(OrderRequest memory req, bool _isBuy) public {
        if (_isBuy) {
            uint256 buyLast = buyLastIndex[req.marketId][req.limitPrice];
            uint256 buyFirst = buyFirstIndex[req.marketId][req.limitPrice];

            require(
                buyLast > 0 && buyFirst > 0,
                "BaseOrderBook: buyOrderBook queue is empty"
            );
            delete buyOrderBook[req.marketId][req.limitPrice][buyFirst];

            // If the queue is empty after the deletion, set the first & last index to 0
            // for the next order added
            if (
                buyLastIndex[req.marketId][req.limitPrice] ==
                buyFirstIndex[req.marketId][req.limitPrice]
            ) {
                buyLastIndex[req.marketId][req.limitPrice] = 0;
                buyFirstIndex[req.marketId][req.limitPrice] = 0;
            } else {
                buyFirstIndex[req.marketId][req.limitPrice]++;
            }
        } else {
            uint256 sellLast = sellLastIndex[req.marketId][req.limitPrice];
            uint256 sellFirst = sellFirstIndex[req.marketId][req.limitPrice];
            require(
                sellLast > 0 && sellFirst > 0,
                "BaseOrderBook: sellOrderBook queue is empty"
            );
            delete sellOrderBook[req.marketId][req.limitPrice][sellFirst];

            // If the queue is empty after the deletion, set the first & last index to 0
            // for the next order added
            if (
                sellLastIndex[req.marketId][req.limitPrice] ==
                sellFirstIndex[req.marketId][req.limitPrice]
            ) {
                sellLastIndex[req.marketId][req.limitPrice] = 0;
                sellFirstIndex[req.marketId][req.limitPrice] = 0;
            } else {
                sellFirstIndex[req.marketId][req.limitPrice]++;
            }
        }
    }
}
