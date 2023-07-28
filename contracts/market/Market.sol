// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract Market {
    struct MarketInfo {
        uint256 marketId;
        uint256 baseAssetId; // synthetic
        uint256 quoteAssetId; // synthetic
        uint256 longReserveAssetId; // real liquidity
        uint256 shortReserveAssetId; // real liquidity
    }

    mapping(uint256 => MarketInfo) public markets; // marketId => MarketInfo
    mapping(uint256 => uint256) public priceTickSizes; // marketId => priceTickSize (in USD, 10^8)

    function getMarketInfo(
        uint256 _marketId
    ) external view returns (MarketInfo memory) {
        return markets[_marketId];
    }

    function getPriceTickSize(
        uint256 _marketId
    ) external view returns (uint256) {
        return priceTickSizes[_marketId];
    }

    function setPriceTickSize(
        uint256 _marketId,
        uint256 _tickSizeInUsd
    ) public {
        // TODO: only owner
        priceTickSizes[_marketId] = _tickSizeInUsd;
    }
}
