// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/Context.sol";

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
        public orderSizeInUsdForPriceTick; // indexAssetId => price => sum(sizeDeltaAbs) // TODO: 일단 USD 단위로 기록

    mapping(uint256 => uint256) public priceTickSizes; // indexAssetId => priceTickSize (in USD, 10^8 decimals)

    // ------------------------------------------- Orderbook Queue Data Type ------------------------------------------
    mapping(uint256 => mapping(uint256 => uint256)) public buyFirstIndex; // indexAssetId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public buyLastIndex; // indexAssetId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public sellFirstIndex; // indexAssetId => price => queue index
    mapping(uint256 => mapping(uint256 => uint256)) public sellLastIndex; // indexAssetId => price => queue index

    // FIXME: 맵핑 방식에서도 초기화 필요 (특정 자산Id, 인덱스에 처음 추가 시 초기화 필요)
    // uint256 buyFirst = 1;
    // uint256 buyLast = 0;
    // uint256 sellFirst = 1;
    // uint256 sellLast = 0;

    // FIXME: temporary
    function initializeIndices(uint256 _priceTick) public {
        buyFirstIndex[ETH_ID][_priceTick] = 1;
        buyLastIndex[ETH_ID][_priceTick] = 0;
        sellFirstIndex[ETH_ID][_priceTick] = 1;
        sellLastIndex[ETH_ID][_priceTick] = 0;
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
            // buyLastIndex[_request.indexAssetId][_request.limitPrice]++;
            uint256 buyLast = ++buyLastIndex[_request.indexAssetId][
                _request.limitPrice
            ];

            buyOrderBook[_request.indexAssetId][_request.limitPrice][
                buyLast
            ] = _request;
        } else {
            // sellLastIndex[_request.indexAssetId][_request.limitPrice]++;
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
                buyLast > buyFirst,
                "BaseOrderBook: buyOrderBook queue is empty"
            );
            delete buyOrderBook[_request.indexAssetId][_request.limitPrice][
                buyFirst
            ];

            buyFirstIndex[_request.indexAssetId][_request.limitPrice]++;
        } else {
            uint256 sellLast = sellLastIndex[_request.indexAssetId][
                _request.limitPrice
            ];
            uint256 sellFirst = sellFirstIndex[_request.indexAssetId][
                _request.limitPrice
            ];
            require(
                sellLast > sellFirst,
                "BaseOrderBook: sellOrderBook queue is empty"
            );
            delete sellOrderBook[_request.indexAssetId][_request.limitPrice][
                sellFirst
            ];

            sellFirstIndex[_request.indexAssetId][_request.limitPrice]++;
        }
    }
}
