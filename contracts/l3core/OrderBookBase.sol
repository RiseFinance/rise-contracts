// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/Context.sol";

abstract contract OrderBookBase is Context {
    mapping(address => uint256) public traderOrderRequestCounts; // userAddress => orderRequestCount (limit order)

    mapping(address => mapping(uint256 => OrderRequest)) public pendingOrders; // userAddress => traderOrderRequestCounts => Order (pending orders by trader)

    mapping(uint256 => mapping(uint256 => mapping(uint256 => OrderRequest)))
        public buyOrderBook; // indexAssetId => price => queue index => OrderRequest (Global Queue)
    mapping(uint256 => mapping(uint256 => mapping(uint256 => OrderRequest)))
        public sellOrderBook; // indexAssetId => price => queue index => OrderRequest (Global Queue)

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

    function getOrder(bool _isBuy, uint256 _indexAssetId, uint256 _price)
        public
        view
        returns (OrderRequest memory)
    {
        if (_isBuy) {
            return buyOrderBook[_indexAssetId][_price][
                buyFirstIndex[_indexAssetId][_price]
            ];
        } else {
            return sellOrderBook[_indexAssetId][_price][
                sellFirstIndex[_indexAssetId][_price]
            ];
        }
    }

    function enqueueOrderBook(OrderRequest memory request, bool isBuy) public returns (uint256){
        if (isBuy) {
            // buyLastIndex[request.indexAssetId][request.limitPrice]++;
            uint256 buyLast = ++buyLastIndex[request.indexAssetId][
                request.limitPrice
            ];

            buyOrderBook[request.indexAssetId][request.limitPrice][
                buyLast
            ] = request;

            return buyLast;
        } else {
            // sellLastIndex[request.indexAssetId][request.limitPrice]++;
            uint256 sellLast = ++sellLastIndex[request.indexAssetId][
                request.limitPrice
            ];
            sellOrderBook[request.indexAssetId][request.limitPrice][
                sellLast
            ] = request;

            return sellLast;
        }

    }

    function dequeueOrderBook(OrderRequest memory request, bool isBuy) public {
        if (isBuy) {
            uint256 buyLast = buyLastIndex[request.indexAssetId][
                request.limitPrice
            ];
            uint256 buyFirst = buyFirstIndex[request.indexAssetId][
                request.limitPrice
            ];
            require(
                buyLast > buyFirst,
                "BaseOrderBook: buyOrderBook queue is empty"
            );
            delete buyOrderBook[request.indexAssetId][request.limitPrice][
                buyFirst
            ];

            buyFirstIndex[request.indexAssetId][request.limitPrice]++;
        } else {
            uint256 sellLast = sellLastIndex[request.indexAssetId][
                request.limitPrice
            ];
            uint256 sellFirst = sellFirstIndex[request.indexAssetId][
                request.limitPrice
            ];
            require(
                sellLast > sellFirst,
                "BaseOrderBook: sellOrderBook queue is empty"
            );
            delete sellOrderBook[request.indexAssetId][request.limitPrice][
                sellFirst
            ];

            sellFirstIndex[request.indexAssetId][request.limitPrice]++;
        }
    }
}
