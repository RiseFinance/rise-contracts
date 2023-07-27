// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface ITraderVault {
    // onlyOrderHistory
    function getTraderFilledOrderCount(address) external view returns (uint256);

    // onlyOrderHistory
    function setTraderFilledOrderCount(address, uint256) external;

    function getTraderBalance(address, uint256) external view returns (uint256);

    function increaseTraderBalance(address, uint256, uint256) external;

    function decreaseTraderBalance(address, uint256, uint256) external;

    function addLiquidity(uint256, uint256) external;

    function removeLiquidity(uint256, uint256) external;

    function increaseReserveAmounts(uint256, uint256) external;

    function getPositionSizeInUsd(bytes32) external view returns (uint256);

    function updatePosition(
        bytes32,
        uint256,
        uint256,
        uint256,
        bool,
        bool
    ) external;

    function deletePosition(bytes32) external;

    function fillOrder(
        address,
        bool,
        bool,
        bool,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    ) external;

    function settlePnL(
        bytes32,
        bool,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    ) external;

    function updateGlobalPositionState(
        bool,
        bool,
        uint256,
        uint256,
        uint256,
        uint256
    ) external;
}
