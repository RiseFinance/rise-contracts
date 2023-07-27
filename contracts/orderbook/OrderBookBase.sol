// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/Context.sol";
import "hardhat/console.sol";

abstract contract OrderBookBase is Context {
    mapping(address => uint256) public traderOrderRequestCounts; // userAddress => orderRequestCount (limit order)

    mapping(address => mapping(uint256 => OrderRequest)) public pendingOrders; // userAddress => traderOrderRequestCounts => Order (pending orders by trader)

    mapping(uint256 => mapping(uint256 => mapping(uint256 => OrderRequest)))
        internal buyOrderBook; // indexAssetId => price => queue index => OrderRequest (Global Queue)
    mapping(uint256 => mapping(uint256 => mapping(uint256 => OrderRequest)))
        internal sellOrderBook; // indexAssetId => price => queue index => OrderRequest (Global Queue)

    mapping(uint256 => uint256) public maxBidPrice; // indexAssetId => price
    mapping(uint256 => uint256) public minAskPrice; // indexAssetId => price

    mapping(uint256 => mapping(uint256 => uint256))
        public orderSizeInUsdForPriceTick; // indexAssetId => price => sum(sizeDeltaAbs)

    mapping(uint256 => uint256) public priceTickSizes; // indexAssetId => priceTickSize (in USD, 10^8 decimals)

    // ------------------------------------------- Orderbook Queue Data Type ------------------------------------------
    mapping(uint256 => mapping(uint256 => uint256)) public buyFirstIndex; // indexAssetId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public buyLastIndex; // indexAssetId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public sellFirstIndex; // indexAssetId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public sellLastIndex; // indexAssetId => price => queue index

    function setPriceTickSize(
        uint256 _indexAssetId,
        uint256 _tickSizeInUsd
    ) public {
        // TODO: only owner
        priceTickSizes[_indexAssetId] = _tickSizeInUsd;
    }

    // FIXME: temporary
    function setMaxBidPrice(uint256 _indexAssetId, uint256 _price) public {
        maxBidPrice[_indexAssetId] = _price;
    }

    // FIXME: temporary
    function setMinAskPrice(uint256 _indexAssetId, uint256 _price) public {
        minAskPrice[_indexAssetId] = _price;
    }

    function enqueueOrderBook(
        OrderRequest memory _request,
        bool _isBuy
    ) public {
        if (_isBuy) {
            // If it is the first order added in the queue, set the first index to 1
            // for the last index, added below
            if (buyLastIndex[_request.indexAssetId][_request.limitPrice] == 0) {
                buyFirstIndex[_request.indexAssetId][_request.limitPrice] = 1;
            }

            uint256 buyLast = ++buyLastIndex[_request.indexAssetId][
                _request.limitPrice
            ];

            buyOrderBook[_request.indexAssetId][_request.limitPrice][
                buyLast
            ] = _request;
        } else {
            // If it is the first order added in the queue, set the first index to 1
            // for the last index, added below
            if (
                sellLastIndex[_request.indexAssetId][_request.limitPrice] == 0
            ) {
                sellFirstIndex[_request.indexAssetId][_request.limitPrice] = 1;
            }

            uint256 sellLast = ++sellLastIndex[_request.indexAssetId][
                _request.limitPrice
            ];
            sellOrderBook[_request.indexAssetId][_request.limitPrice][
                sellLast
            ] = _request;
        }
        orderSizeInUsdForPriceTick[_request.indexAssetId][
            _request.limitPrice
        ] += _request.sizeAbsInUsd;
    }

    function dequeueOrderBook(
        OrderRequest memory _request,
        bool _isBuy
    ) public {
        if (_isBuy) {
            uint256 buyLast = buyLastIndex[_request.indexAssetId][
                _request.limitPrice
            ];
            uint256 buyFirst = buyFirstIndex[_request.indexAssetId][
                _request.limitPrice
            ];

            require(
                buyLast > 0 && buyFirst > 0,
                "BaseOrderBook: buyOrderBook queue is empty"
            );
            delete buyOrderBook[_request.indexAssetId][_request.limitPrice][
                buyFirst
            ];

            // If the queue is empty after the deletion, set the first & last index to 0
            // for the next order added
            if (
                buyLastIndex[_request.indexAssetId][_request.limitPrice] ==
                buyFirstIndex[_request.indexAssetId][_request.limitPrice]
            ) {
                buyLastIndex[_request.indexAssetId][_request.limitPrice] = 0;
                buyFirstIndex[_request.indexAssetId][_request.limitPrice] = 0;
            } else {
                buyFirstIndex[_request.indexAssetId][_request.limitPrice]++;
            }
        } else {
            uint256 sellLast = sellLastIndex[_request.indexAssetId][
                _request.limitPrice
            ];
            uint256 sellFirst = sellFirstIndex[_request.indexAssetId][
                _request.limitPrice
            ];
            require(
                sellLast > 0 && sellFirst > 0,
                "BaseOrderBook: sellOrderBook queue is empty"
            );
            delete sellOrderBook[_request.indexAssetId][_request.limitPrice][
                sellFirst
            ];

            // If the queue is empty after the deletion, set the first & last index to 0
            // for the next order added
            if (
                sellLastIndex[_request.indexAssetId][_request.limitPrice] ==
                sellFirstIndex[_request.indexAssetId][_request.limitPrice]
            ) {
                sellLastIndex[_request.indexAssetId][_request.limitPrice] = 0;
                sellFirstIndex[_request.indexAssetId][_request.limitPrice] = 0;
            } else {
                sellFirstIndex[_request.indexAssetId][_request.limitPrice]++;
            }
        }
    }
}
