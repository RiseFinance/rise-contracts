// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceFeed {
    struct Price {
        uint256 price;
        uint256 timestamp;
    }

    function setPrice(uint256 assetId, uint256 price) external;

    function getPrice(uint256 assetId) external view returns (uint256);

    function getTimestamp(uint256 assetId) external view returns (uint256);

    function getPrices(
        uint256[] calldata assetIds
    ) external view returns (Price[] memory);

    function getTimestamps(
        uint256[] calldata assetIds
    ) external view returns (uint256[] memory);
}
