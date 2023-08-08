// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";

import "../token/RM.sol";
import "./Market.sol";

// Deals with listing new markets and updating existing ones
// * Listing new markets
// * Asset ID ++, market token addresses register, LP pool register, LP token generating, etc.

contract ListingManager {
    // TODO: create LP token contract for each market
    // TODO: register token if not registered

    function createRisePerpsMarket(
        MarketInfo memory m
    ) public returns (MarketInfo memory) {
        bytes32 salt = keccak256(
            abi.encode(
                "RISE_PERPS_MARKET",
                m.marketId,
                m.baseAssetId,
                m.quoteAssetId
            )
        );

        RiseMarketMaker rm = new RiseMarketMaker{salt: salt}(); // market maker token

        MarketInfo memory newMarket = MarketInfo(
            m.marketId,
            m.priceTickSize,
            m.baseAssetId,
            m.quoteAssetId,
            m.longReserveAssetId,
            m.shortReserveAssetId,
            m.marginAssetId,
            address(rm)
        );

        return newMarket;
    }
}
