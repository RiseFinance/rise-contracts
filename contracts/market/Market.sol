// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract Market {
    struct MarketInfo {
        uint256 marketId;
        uint256 baseAssetId;
        uint256 quoteAssetId;
        uint256 longReserveAssetId;
        uint256 shortReserveAssetId;
    }

    mapping(uint256 => MarketInfo) public markets; // marketId => MarketInfo
    mapping(uint256 => uint256) public priceTickSizes; // indexAssetId => priceTickSize (in USD, 10^8 decimals)

    function getMarketInfo(
        uint256 _marketId
    ) external view returns (MarketInfo memory) {
        return markets[_marketId];
    }

    function getPriceTickSize(
        uint256 _indexAssetId
    ) external view returns (uint256) {
        return priceTickSizes[_indexAssetId];
    }

    function setPriceTickSize(
        uint256 _indexAssetId,
        uint256 _tickSizeInUsd
    ) public {
        // TODO: only owner
        priceTickSizes[_indexAssetId] = _tickSizeInUsd;
    }
}
