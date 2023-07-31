// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../token/RMM.sol";
import "./Market.sol";

// Deals with listing new markets and updating existing ones
// * Listing new markets
// * Asset ID ++, market token addresses register, LP pool register, LP token generating, etc.

contract MarketFactory {
    // TODO: create LP token contract for each market

    function createRisePerpsMarket(
        Market.MarketInfo memory m
    ) public returns (Market.MarketInfo memory) {
        bytes32 salt = keccak256(
            abi.encode(
                "RISE_PERPS_MARKET",
                m.marketId,
                m.baseAssetId,
                m.quoteAssetId
            )
        );

        RiseMarketMaker rmm = new RiseMarketMaker{salt: salt}(); // market maker token

        Market.MarketInfo memory newMarket = Market.MarketInfo(
            m.marketId,
            m.priceTickSize,
            m.baseAssetId,
            m.quoteAssetId,
            m.longReserveAssetId,
            m.shortReserveAssetId,
            m.marginAssetId,
            address(rmm)
        );

        return newMarket;
    }
}
