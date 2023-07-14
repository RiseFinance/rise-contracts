// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./interfaces/IPriceManager.sol";
import "./L3Vault.sol";

import "hardhat/console.sol";

contract PriceManager is IPriceManager {
    uint256 public constant PRICE_BUFFER_PRECISION = 10 ** 8;
    uint256 public constant USD_PRECISION = 10 ** 20;
    uint256 public constant DECAY_CONSTANT =
        (PRICE_BUFFER_PRECISION / 100) / 300; // 1% decay per 5 miniutes
    uint256 public constant PRICE_BUFFER_DELTA_TO_SIZE =
        ((10 ** 6) * USD_PRECISION) / (PRICE_BUFFER_PRECISION / 100); // 1% price buffer per 10^6 USD

    L3Vault public l3Vault;

    mapping(address => bool) public isKeeper;
    mapping(uint256 => uint256) public indexPrice;
    mapping(uint256 => uint256) public priceBufferUpdatedTime;
    mapping(uint256 => int256) public lastPriceBuffer;

    event Execution(uint256 assetId, int256 price);

    constructor(address _keeperAddress, address _l3VaultAddress) {
        isKeeper[_keeperAddress] = true;
        l3Vault = L3Vault(_l3VaultAddress);
    }

    modifier onlyKeeper() {
        require(isKeeper[msg.sender], "Should be called by keeper");
        _;
    }

    function setPrice(
        uint256[] calldata _assetId,
        uint256[] calldata _price // new index price from the data source
    ) external override onlyKeeper {
        require(_assetId.length == _price.length, "Wrong input");
        uint256 l = _assetId.length;
        for (uint256 i = 0; i < uint256(l); i++) {
            require(_price[i] > 0, "price has to be positive");

            int256 currentPriceBuffer = getPriceBuffer(_assetId[i]); // % of price shift
            int256 currentPriceBufferInUsd = (int256(_price[i]) *
                currentPriceBuffer) / int256(PRICE_BUFFER_PRECISION);

            // int prevMarkPrice = indexPrice[_assetId[i]] +
            //     currentPriceBufferInUsd;
            uint256 currentMarkPrice = uint256(
                int256(_price[i]) + currentPriceBufferInUsd
            );

            uint256 markPriceWithLimitOrderPriceImpact;

            bool checkBuyOrderBook = _price[i] < indexPrice[_assetId[i]];

            markPriceWithLimitOrderPriceImpact = l3Vault
                .executeLimitOrdersAndGetFinalMarkPrice(
                    checkBuyOrderBook, // isBuy
                    _assetId[i],
                    uint256(_price[i]),
                    uint256(currentMarkPrice)
                );

            // TODO: set price with markPriceWithLimitOrderPriceImpact
            int256 newPriceBuffer = ((int256(
                markPriceWithLimitOrderPriceImpact
            ) - int256(_price[i])) * int256(PRICE_BUFFER_PRECISION)) /
                int256(_price[i]);
            setPriceBuffer(_assetId[i], newPriceBuffer);
            indexPrice[_assetId[i]] = _price[i];
        }
    }

    function getPriceBuffer(
        uint256 _assetId
    ) public view override returns (int256) {
        int256 elapsedTime = int256(
            block.timestamp - priceBufferUpdatedTime[_assetId]
        );
        int256 decayedAmount = elapsedTime * int256(DECAY_CONSTANT);
        int256 absLastPriceBuffer = lastPriceBuffer[_assetId] >= 0
            ? lastPriceBuffer[_assetId]
            : -lastPriceBuffer[_assetId];
        if (decayedAmount >= absLastPriceBuffer) {
            return 0;
        }
        if (lastPriceBuffer[_assetId] >= 0) {
            return lastPriceBuffer[_assetId] - decayedAmount;
        } else {
            return lastPriceBuffer[_assetId] + decayedAmount;
        }
    }

    function setPriceBuffer(uint256 _assetId, int256 value) internal {
        lastPriceBuffer[_assetId] = value;
        priceBufferUpdatedTime[_assetId] = block.timestamp;
    }

    function getIndexPrice(
        uint256 _assetId
    ) external view override returns (uint256) {
        return indexPrice[_assetId];
    }

    function getMarkPrice(
        uint256 _assetId
    ) public view override returns (uint256) {
        int256 newPriceBuffer = getPriceBuffer(_assetId);
        int256 newPriceBufferInUsd = (int256(indexPrice[_assetId]) *
            newPriceBuffer) / int256(PRICE_BUFFER_PRECISION);
        return uint256(int256(indexPrice[_assetId]) + newPriceBufferInUsd);
    }

    function getAverageExecutionPrice(
        uint256 _assetId,
        uint256 _size,
        bool _isBuy
    ) external override returns (uint256) {
        uint256 price = getMarkPrice(_assetId);
        // require first bit of _size is 0
        require(_size < 2 ** 255, "size overflow");
        require(price > 0, "price not set");
        int256 intSize = _isBuy ? int256(_size) : -int256(_size);
        int256 priceBufferChange = intSize / int256(PRICE_BUFFER_DELTA_TO_SIZE);
        setPriceBuffer(_assetId, getPriceBuffer(_assetId) + priceBufferChange);
        int256 averageExecutedPrice = int256(price) +
            (int256(price) * priceBufferChange) /
            2 /
            int256(PRICE_BUFFER_PRECISION);
        require(averageExecutedPrice > 0, "price underflow");
        emit Execution(_assetId, averageExecutedPrice);
        return uint256(averageExecutedPrice);
    }
}
