// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract TokenInfo {
    uint256 globalTokenIdCounter;

    mapping(uint256 => uint256) private tokenDecimals; // TODO: listing restriction needed
    mapping(address => uint256) private tokenAddressToAssetId;
    mapping(uint256 => address) private assetIdToTokenAddress;

    function getTokenDecimals(
        uint256 _assetId
    ) external view returns (uint256) {
        return tokenDecimals[_assetId];
    }

    function getAssetIdFromTokenAddress(
        address _tokenAddress
    ) external view returns (uint256) {
        return tokenAddressToAssetId[_tokenAddress];
    }

    function getTokenAddressFromAssetId(
        uint256 _assetId
    ) external view returns (address) {
        return assetIdToTokenAddress[_assetId];
    }

    // TODO: onlyAdmin
    // TODO: check- to store token ticker and name in the contract storage?
    function registerToken(
        address _tokenAddress,
        uint256 _tokenDecimals
    ) external {
        uint256 assetId = globalTokenIdCounter;
        tokenDecimals[assetId] = _tokenDecimals;
        tokenAddressToAssetId[_tokenAddress] = assetId;
        assetIdToTokenAddress[assetId] = _tokenAddress;

        globalTokenIdCounter++;
    }
}
