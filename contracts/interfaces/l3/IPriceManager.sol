// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceManager {
    function setPrice(uint256[] calldata, uint256[] calldata, bool) external;

    function getPriceBuffer(uint256) external view returns (int256);

    function getIndexPrice(uint256) external view returns (uint256);

    function getMarkPrice(uint256) external view returns (uint256);

    function getAverageExecutionPrice(
        uint256,
        uint256,
        bool
    ) external returns (uint256);
}
