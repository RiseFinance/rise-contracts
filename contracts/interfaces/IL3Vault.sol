// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IL3Vault {
    function isAssetIdValid(uint256) external pure returns (bool);

    function getTraderBalance(address, uint256) external view returns (uint256);

    function increaseTraderBalance(address, uint256, uint256) external;

    function decreaseTraderBalance(address, uint256, uint256) external;
}
