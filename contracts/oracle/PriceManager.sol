// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/Context.sol";
import "../orderbook/OrderBook.sol";
import "hardhat/console.sol";

contract PriceManager is Context {
    OrderBook public orderBook;

    mapping(address => bool) public isPriceKeeper;
    mapping(uint256 => uint256) public indexPrice;
    mapping(uint256 => uint256) public priceBufferUpdatedTime;
    mapping(uint256 => int256) public lastPriceBuffer;

    event Execution(uint256 marketId, int256 price);

    constructor(address _orderBook, address _keeperAddress) {
        orderBook = OrderBook(_orderBook);
        isPriceKeeper[_keeperAddress] = true;
    }

    modifier onlyPriceKeeper() {
        require(
            isPriceKeeper[msg.sender],
            "PriceManager: Should be called by keeper"
        );
        _;
    }

    function setPrice(
        uint256[] calldata _marketId,
        uint256[] calldata _price, // new index price from the data source
        bool _isInitialize
    ) external onlyPriceKeeper {
        require(_marketId.length == _price.length, "PriceManager: Wrong input");
        uint256 l = _marketId.length;

        for (uint256 i = 0; i < uint256(l); i++) {
            require(_price[i] > 0, "PriceManager: price has to be positive");

            int256 currentPriceBuffer = getPriceBuffer(_marketId[i]); // % of price shift

            int256 currentPriceBufferInUsd = (int256(_price[i]) *
                currentPriceBuffer) / int256(PRICE_BUFFER_PRECISION);

            // int prevMarkPrice = indexPrice[_marketId[i]] +
            //     currentPriceBufferInUsd;
            uint256 currentMarkPrice = uint256(
                int256(_price[i]) + currentPriceBufferInUsd
            );

            uint256 markPriceWithLimitOrderPriceImpact;

            bool checkBuyOrderBook = _price[i] < indexPrice[_marketId[i]];

            if (_isInitialize) {
                markPriceWithLimitOrderPriceImpact = currentMarkPrice;
            } else {
                markPriceWithLimitOrderPriceImpact = orderBook
                    .executeLimitOrdersAndGetFinalMarkPrice(
                        checkBuyOrderBook, // isBuy
                        _marketId[i],
                        uint256(_price[i]),
                        uint256(currentMarkPrice)
                    );
            }

            console.log(
                "PriceManager: markPriceWithLimitOrderPriceImpact: ",
                markPriceWithLimitOrderPriceImpact
            );

            // TODO: set price with markPriceWithLimitOrderPriceImpact
            int256 newPriceBuffer = ((int256(
                markPriceWithLimitOrderPriceImpact
            ) - int256(_price[i])) * int256(PRICE_BUFFER_PRECISION)) /
                int256(_price[i]);

            setPriceBuffer(_marketId[i], newPriceBuffer);
            console.log(
                "PriceManager: newPriceBuffer: ",
                uint256(newPriceBuffer)
            );
            console.log("PriceManager: _price[i]: ", _price[i]);
            console.log("\n");
            indexPrice[_marketId[i]] = _price[i];
        }
    }

    function getPriceBuffer(uint256 _marketId) public view returns (int256) {
        int256 elapsedTime = int256(
            block.timestamp - priceBufferUpdatedTime[_marketId]
        );
        int256 decayedAmount = elapsedTime * int256(DECAY_CONSTANT);
        int256 absLastPriceBuffer = lastPriceBuffer[_marketId] >= 0
            ? lastPriceBuffer[_marketId]
            : -lastPriceBuffer[_marketId];
        if (decayedAmount >= absLastPriceBuffer) {
            return 0;
        }
        if (lastPriceBuffer[_marketId] >= 0) {
            return lastPriceBuffer[_marketId] - decayedAmount;
        } else {
            return lastPriceBuffer[_marketId] + decayedAmount;
        }
    }

    function setPriceBuffer(uint256 _marketId, int256 _value) internal {
        lastPriceBuffer[_marketId] = _value;
        priceBufferUpdatedTime[_marketId] = block.timestamp;
    }

    function getIndexPrice(uint256 _marketId) external view returns (uint256) {
        return indexPrice[_marketId];
    }

    function getMarkPrice(uint256 _marketId) public view returns (uint256) {
        int256 newPriceBuffer = getPriceBuffer(_marketId);
        int256 newPriceBufferInUsd = (int256(indexPrice[_marketId]) *
            newPriceBuffer) / int256(PRICE_BUFFER_PRECISION);
        return uint256(int256(indexPrice[_marketId]) + newPriceBufferInUsd);
    }

    function getAverageExecutionPrice(
        uint256 _marketId,
        uint256 _sizeInUsd,
        bool _isBuy
    ) external returns (uint256) {
        uint256 price = getMarkPrice(_marketId);
        // require first bit of _size is 0
        require(_sizeInUsd < 2 ** 255, "PriceManager: size overflow");
        require(price > 0, "PriceManager: price not set");
        int256 intSize = _isBuy ? int256(_sizeInUsd) : -int256(_sizeInUsd);
        int256 priceBufferChange = intSize / int256(PRICE_BUFFER_DELTA_TO_SIZE);
        setPriceBuffer(
            _marketId,
            getPriceBuffer(_marketId) + priceBufferChange
        );
        int256 averageExecutedPrice = int256(price) +
            (int256(price) * priceBufferChange) /
            2 /
            int256(PRICE_BUFFER_PRECISION);
        require(averageExecutedPrice > 0, "PriceManager: price underflow");
        emit Execution(_marketId, averageExecutedPrice);
        return uint256(averageExecutedPrice);
    }
}
