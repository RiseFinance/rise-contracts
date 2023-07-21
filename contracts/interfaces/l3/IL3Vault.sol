// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IL3Vault {
    struct OrderContext {
        bool _isLong;
        bool _isIncrease;
        uint256 _indexAssetId;
        uint256 _collateralAssetId;
        uint256 _sizeAbsInUsd;
        uint256 _collateralAbsInUsd;
        uint256 _limitPrice; // empty for market orders
    }

    function setAssetIdCounter(uint256) external;

    function isAssetIdValid(uint256) external view returns (bool);

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

    function validateIncreaseExecution(OrderContext calldata) external view;

    function validateDecreaseExecution(
        OrderContext calldata,
        bytes32,
        uint256
    ) external view;
}
