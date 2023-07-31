// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./Market.sol";

contract TokenInfo {
    mapping(uint256 => uint256) public tokenDecimals; // TODO: listing restriction needed
    mapping(address => uint256) public tokenAddressToId;
    Market public market;

    function getTokenIdFromAddress(
        address _tokenAddress
    ) external view returns (uint256) {
        return tokenAddressToId[_tokenAddress];
    }

    function getBaseTokenDecimals(
        uint256 _marketId
    ) external view returns (uint256) {
        Market.MarketInfo memory marketInfo = market.getMarketInfo(_marketId);
        return tokenDecimals[marketInfo.baseAssetId];
    }
}
