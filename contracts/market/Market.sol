// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract Market {
    // TODO: check - base asset, quote asset size decimals for submitting an order
    struct MarketInfo {
        uint256 marketId;
        uint256 priceTickSize; // in USD, 10^8
        uint256 baseAssetId; // synthetic
        uint256 quoteAssetId; // synthetic
        uint256 longReserveAssetId; // real liquidity
        uint256 shortReserveAssetId; // real liquidity
        uint256 marginAssetId;
        address marketMakerToken;
    }
}
