// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract TokenInfo {
    mapping(uint256 => uint256) public tokenDecimals; // TODO: listing restriction needed
    mapping(address => uint256) public tokenAddressToId;

    function getTokenIdFromAddress(
        address _tokenAddress
    ) external view returns (uint256) {
        return tokenAddressToId[_tokenAddress];
    }
}
