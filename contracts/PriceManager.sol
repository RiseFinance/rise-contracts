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
    mapping(uint => uint) public indexPrice;
    mapping(uint => uint) public priceBufferUpdatedTime;
    mapping(uint => int) public lastPriceBuffer;

    event Execution(uint assetId, int price);

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
        for (uint i = 0; i < uint(l); i++) {
            require(_price[i] > 0, "price has to be positive");

            int currentPriceBuffer = getPriceBuffer(_assetId[i]); // % of price shift
            int currentPriceBufferInUsd = (int256(_price[i]) *
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
            int newPriceBuffer = ((int256(markPriceWithLimitOrderPriceImpact) -
                int256(_price[i])) * int256(PRICE_BUFFER_PRECISION)) /
                int256(_price[i]);
            setPriceBuffer(_assetId[i], newPriceBuffer);
            indexPrice[_assetId[i]] = _price[i];
        }
    }

    function getPriceBuffer(uint _assetId) public view override returns (int) {
        int elapsedTime = int(
            block.timestamp - priceBufferUpdatedTime[_assetId]
        );
        int decayedAmount = elapsedTime * int256(DECAY_CONSTANT);
        int absLastPriceBuffer = lastPriceBuffer[_assetId] >= 0
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

    function setPriceBuffer(uint _assetId, int value) internal {
        lastPriceBuffer[_assetId] = value;
        priceBufferUpdatedTime[_assetId] = block.timestamp;
    }

    function getIndexPrice(
        uint _assetId
    ) external view override returns (uint256) {
        return indexPrice[_assetId];
    }

    function getMarkPrice(
        uint _assetId
    ) public view override returns (uint256) {
        int newPriceBuffer = getPriceBuffer(_assetId);
        int newPriceBufferInUsd = (int256(indexPrice[_assetId]) *
            newPriceBuffer) / int256(PRICE_BUFFER_PRECISION);
        return uint256(int256(indexPrice[_assetId]) + newPriceBufferInUsd);
    }

    function getAverageExecutionPrice(
        uint _assetId,
        uint _size,
        bool _isBuy
    ) external override returns (uint256) {
        uint price = getMarkPrice(_assetId);
        // require first bit of _size is 0
        require(_size < 2 ** 255, "size overflow");
        require(price > 0, "price not set");
        int intSize = _isBuy ? int(_size) : -int(_size);
        int priceBufferChange = intSize / int256(PRICE_BUFFER_DELTA_TO_SIZE);
        setPriceBuffer(_assetId, getPriceBuffer(_assetId) + priceBufferChange);
        int averageExecutedPrice = int(price) +
            (int(price) * priceBufferChange) /
            2 /
            int(PRICE_BUFFER_PRECISION);
        require(averageExecutedPrice > 0, "price underflow");
        emit Execution(_assetId, averageExecutedPrice);
        return uint256(averageExecutedPrice);
    }
}
