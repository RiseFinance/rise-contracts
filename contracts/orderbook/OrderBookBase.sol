// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";
import "../order/OrderUtils.sol";
import "hardhat/console.sol";

abstract contract OrderBookBase is OrderUtils {
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

    function enqueueOrderBook(
        OrderRequest memory _request,
        bool _isBuy
    ) public {
        if (_isBuy) {
            // If it is the first order added in the queue, set the first index to 1
            // for the last index, added below
            if (buyLastIndex[_request.marketId][_request.limitPrice] == 0) {
                buyFirstIndex[_request.marketId][_request.limitPrice] = 1;
            }

            uint256 buyLast = ++buyLastIndex[_request.marketId][
                _request.limitPrice
            ];

            buyOrderBook[_request.marketId][_request.limitPrice][
                buyLast
            ] = _request;
        } else {
            // If it is the first order added in the queue, set the first index to 1
            // for the last index, added below
            if (sellLastIndex[_request.marketId][_request.limitPrice] == 0) {
                sellFirstIndex[_request.marketId][_request.limitPrice] = 1;
            }

            uint256 sellLast = ++sellLastIndex[_request.marketId][
                _request.limitPrice
            ];
            sellOrderBook[_request.marketId][_request.limitPrice][
                sellLast
            ] = _request;
        }
        orderSizeForPriceTick[_request.marketId][
            _request.limitPrice
        ] += _request.sizeAbs;
    }

    function dequeueOrderBook(
        OrderRequest memory _request,
        bool _isBuy
    ) public {
        if (_isBuy) {
            uint256 buyLast = buyLastIndex[_request.marketId][
                _request.limitPrice
            ];
            uint256 buyFirst = buyFirstIndex[_request.marketId][
                _request.limitPrice
            ];

            require(
                buyLast > 0 && buyFirst > 0,
                "BaseOrderBook: buyOrderBook queue is empty"
            );
            delete buyOrderBook[_request.marketId][_request.limitPrice][
                buyFirst
            ];

            // If the queue is empty after the deletion, set the first & last index to 0
            // for the next order added
            if (
                buyLastIndex[_request.marketId][_request.limitPrice] ==
                buyFirstIndex[_request.marketId][_request.limitPrice]
            ) {
                buyLastIndex[_request.marketId][_request.limitPrice] = 0;
                buyFirstIndex[_request.marketId][_request.limitPrice] = 0;
            } else {
                buyFirstIndex[_request.marketId][_request.limitPrice]++;
            }
        } else {
            uint256 sellLast = sellLastIndex[_request.marketId][
                _request.limitPrice
            ];
            uint256 sellFirst = sellFirstIndex[_request.marketId][
                _request.limitPrice
            ];
            require(
                sellLast > 0 && sellFirst > 0,
                "BaseOrderBook: sellOrderBook queue is empty"
            );
            delete sellOrderBook[_request.marketId][_request.limitPrice][
                sellFirst
            ];

            // If the queue is empty after the deletion, set the first & last index to 0
            // for the next order added
            if (
                sellLastIndex[_request.marketId][_request.limitPrice] ==
                sellFirstIndex[_request.marketId][_request.limitPrice]
            ) {
                sellLastIndex[_request.marketId][_request.limitPrice] = 0;
                sellFirstIndex[_request.marketId][_request.limitPrice] = 0;
            } else {
                sellFirstIndex[_request.marketId][_request.limitPrice]++;
            }
        }
    }
}
