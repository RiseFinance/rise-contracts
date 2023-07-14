// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./CommonContext.sol";

contract BaseOrderBook is CommonContext {
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

    function enqueueOrderBook(OrderRequest memory request, bool isBuy) public {
        if (isBuy) {
            buyLastIndex[request.indexAssetId][request.limitPrice]++;
            uint256 buyLast = buyLastIndex[request.indexAssetId][
                request.limitPrice
            ];

            buyOrderBook[request.indexAssetId][request.limitPrice][
                buyLast
            ] = request;
        } else {
            sellLastIndex[request.indexAssetId][request.limitPrice]++;
            uint256 sellLast = sellLastIndex[request.indexAssetId][
                request.limitPrice
            ];
            sellOrderBook[request.indexAssetId][request.limitPrice][
                sellLast
            ] = request;
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
            require(buyLast > buyFirst, "L3Vault: buyOrderBook queue is empty");
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
                "L3Vault: sellOrderBook queue is empty"
            );
            delete sellOrderBook[request.indexAssetId][request.limitPrice][
                sellFirst
            ];

            sellFirstIndex[request.indexAssetId][request.limitPrice]++;
        }
    }
}
