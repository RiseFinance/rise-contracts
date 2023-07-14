// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceManager {
    function setPrice(uint256[] calldata, uint256[] calldata) external;

    function getPriceBuffer(uint) external view returns (int256);

    function getIndexPrice(uint) external view returns (uint256);

    function getMarkPrice(uint) external view returns (uint256);

    function getAverageExecutionPrice(
        uint,
        uint256,
        bool
    ) external returns (uint256);
}
