// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";

import "./Market.sol";

contract TokenInfo {
    Market public market;
    uint256 globalTokenIdCounter;

    // mapping(uint256 => uint256) private tokenDecimals; // TODO: listing restriction needed
    mapping(address => uint256) private tokenAddressToAssetId;
    // mapping(uint256 => address) private assetIdToTokenAddress;
    // mapping(uint256 => uint256) private sizeToPriceBufferDeltaMultiplier;
    mapping(uint256 => TokenData) private assetIdToTokenData;

    function getTokenData(
        uint256 _assetId
    ) public view returns (TokenData memory) {
        return assetIdToTokenData[_assetId];
    }

    function getTokenDecimals(uint256 _assetId) public view returns (uint256) {
        return getTokenData(_assetId).decimals;
    }

    function getAssetIdFromTokenAddress(
        address _tokenAddress
    ) public view returns (uint256) {
        return tokenAddressToAssetId[_tokenAddress];
    }

    function getTokenAddressFromAssetId(
        uint256 _assetId
    ) public view returns (address) {
        return getTokenData(_assetId).tokenAddress;
    }

    function getSizeToPriceBufferDeltaMultiplier(
        uint256 _assetId
    ) public view returns (uint256) {
        return getTokenData(_assetId).sizeToPriceBufferDeltaMultiplier;
    }

    function setSizeToPriceBufferDeltaMultiplier(
        uint256 _assetId,
        uint256 _multiplier
    ) public {
        TokenData storage tokenData = sizeToPriceBufferDeltaMultiplier[
            _assetId
        ];
        tokenData.sizeToPriceBufferDeltaMultiplier = _multiplier;
    }

    // TODO: onlyAdmin
    // TODO: check- to store token ticker and name in the contract storage?
    function registerToken(
        address _tokenAddress,
        uint256 _tokenDecimals
    ) external {
        uint256 assetId = globalTokenIdCounter;
        TokenData storage tokenData = assetIdToTokenData[assetId];
        tokenData[assetId] = _tokenDecimals;
        tokenAddressToAssetId[_tokenAddress] = assetId;
        tokenData[assetId] = _tokenAddress;

        globalTokenIdCounter++;
    }

    function getBaseTokenDecimals(
        uint256 _marketId
    ) external view returns (uint256) {
        MarketInfo memory marketInfo = market.getMarketInfo(_marketId);
        return getTokenDecimals(marketInfo.baseAssetId);
    }

    function getBaseTokenSizeToPriceBufferDeltaMultiplier(
        uint256 _marketId
    ) external view returns (uint256) {
        MarketInfo memory marketInfo = market.getMarketInfo(_marketId);
        return getSizeToPriceBufferDeltaMultiplier(marketInfo.baseAssetId);
    }
}
