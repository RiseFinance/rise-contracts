// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract PriceFeed {
    struct Price {
        uint256 price;
        uint256 timestamp;
    }

    mapping(address => bool) public isOperator;

    mapping(uint256 => Price) public prices; // assetId => Price

    function setPrice(uint256 assetId, uint256 price) external {
        require(isOperator[msg.sender], "PriceFeed: not operator");
        prices[assetId] = Price(price, block.timestamp);
    }

    function getPrice(uint256 assetId) external view returns (uint256) {
        return prices[assetId].price;
    }

    function getTimestamp(uint256 assetId) external view returns (uint256) {
        return prices[assetId].timestamp;
    }

    function getPrices(
        uint256[] calldata assetIds
    ) external view returns (Price[] memory) {
        Price[] memory _prices = new Price[](assetIds.length);
        for (uint256 i = 0; i < assetIds.length; i++) {
            _prices[i] = prices[assetIds[i]];
        }
        return _prices;
    }

    function getTimestamps(
        uint256[] calldata assetIds
    ) external view returns (uint256[] memory) {
        uint256[] memory _timestamps = new uint256[](assetIds.length);
        for (uint256 i = 0; i < assetIds.length; i++) {
            _timestamps[i] = prices[assetIds[i]].timestamp;
        }
        return _timestamps;
    }
}
