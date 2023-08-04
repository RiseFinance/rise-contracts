// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";

contract Market {
    mapping(uint256 => MarketInfo) public markets; // marketId => MarketInfo
    uint256 public globalMarketIdCounter = 0;

    function getMarketInfo(
        uint256 _marketId
    ) external view returns (MarketInfo memory) {
        return markets[_marketId];
    }

    function getMarketIdCounter() external view returns (uint256) {
        return globalMarketIdCounter;
    }

    function getPriceTickSize(
        uint256 _marketId
    ) external view returns (uint256) {
        MarketInfo memory marketInfo = markets[_marketId];
        require(
            marketInfo.priceTickSize != 0,
            "MarketVault: priceTickSize not set"
        );
        return marketInfo.priceTickSize;
    }

    function setPriceTickSize(
        uint256 _marketId,
        uint256 _tickSizeInUsd
    ) public {
        // TODO: only owner
        // TODO: event - shows the previous tick size
        MarketInfo storage marketInfo = markets[_marketId];
        marketInfo.priceTickSize = _tickSizeInUsd;
    }
}
