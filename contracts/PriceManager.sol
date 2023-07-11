// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./interfaces/IPriceManager.sol";

import "hardhat/console.sol";

contract PriceManager is IPriceManager {
    int public constant PRICE_BUFFER_PRECISION = 10 ** 6;
    int public constant SIZE_PRECISION = 10 ** 3;
    int public constant DECAY_CONSTANT = (PRICE_BUFFER_PRECISION / 100) / 300;
    // 1% decay per 5 miniutes
    int public constant PRICE_BUFFER_CHANGE_CONSTANT =
        ((10 ** 6) * SIZE_PRECISION) / (PRICE_BUFFER_PRECISION / 100);
    // 1% price buffer per 10^6 USD

    mapping(address => bool) public isKeeper;
    mapping(uint => int) public indexPrice;
    mapping(uint => uint) public priceBufferUpdatedTime;
    mapping(uint => int) public lastPriceBuffer;

    event Execution(uint assetId, int price);

    constructor(address _keeperAddress) {
        isKeeper[_keeperAddress] = true;
    }

    modifier onlyKeeper() {
        require(isKeeper[msg.sender], "Should be called by keeper");
        _;
    }

    function setPrice(
        uint[] calldata _assetId,
        int[] calldata _price
    ) external override onlyKeeper {
        require(_assetId.length == _price.length, "Wrong input");
        uint l = _assetId.length;
        for (uint i = 0; i < uint(l); i++) {
            require(_price[i] > 0, "price has to be positive");
            indexPrice[_assetId[i]] = _price[i];
        }
    }

    function getPriceBuffer(uint _assetId) public view override returns (int) {
        int elapsedTime = int(
            block.timestamp - priceBufferUpdatedTime[_assetId]
        );
        int decayedAmount = elapsedTime * DECAY_CONSTANT;
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

    function updatePriceBuffer(uint _assetId, int changedAmount) internal {
        int currentPriceBuffer = getPriceBuffer(_assetId);
        lastPriceBuffer[_assetId] = currentPriceBuffer + changedAmount;
        priceBufferUpdatedTime[_assetId] = block.timestamp;
    }

    function getIndexPrice(uint _assetId) external view override returns (int) {
        return indexPrice[_assetId];
    }

    function getMarkPrice(uint _assetId) public view override returns (int) {
        int newPriceBuffer = getPriceBuffer(_assetId);
        int newPriceBufferInUsd = (indexPrice[_assetId] * newPriceBuffer) /
            PRICE_BUFFER_PRECISION;
        return indexPrice[_assetId] + newPriceBufferInUsd;
    }

    function getAverageExecutionPrice(
        uint _assetId,
        uint size,
        bool isBuy
    ) external override returns (uint256) {
        int price = getMarkPrice(_assetId);
        // TODO: int 형변환 분기처리
        int priceBufferChange = int(size) / PRICE_BUFFER_CHANGE_CONSTANT;
        int averageExecutedPrice;
        if (isBuy) {
            updatePriceBuffer(_assetId, priceBufferChange);
            averageExecutedPrice =
                price +
                (price * priceBufferChange) /
                2 /
                PRICE_BUFFER_PRECISION;
        } else {
            require(
                priceBufferChange < PRICE_BUFFER_PRECISION,
                "price underflow"
            );
            updatePriceBuffer(_assetId, -priceBufferChange);
            averageExecutedPrice =
                price -
                (price * priceBufferChange) /
                2 /
                PRICE_BUFFER_PRECISION;
        }
        console.log(uint(averageExecutedPrice));
        emit Execution(_assetId, averageExecutedPrice);
        return uint256(averageExecutedPrice);
    }
}
