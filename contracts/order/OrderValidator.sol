// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../position/PositionVault.sol";
import "../global/GlobalState.sol";
import "../risepool/RisePool.sol";

contract OrderValidator {
    PositionVault public positionVault;
    GlobalState public globalState;
    RisePool public risePool;

    function validateIncreaseExecution(OrderParams calldata p) external view {
        uint256 poolAmount = p._isLong
            ? risePool.getLongPoolAmount(p._marketId)
            : risePool.getShortPoolAmount(p._marketId);

        uint256 reserveAmount = p._isLong
            ? risePool.getLongReserveAmount(p._marketId)
            : risePool.getShortReserveAmount(p._marketId);

        uint256 maxLongCapacity = positionVault.maxLongCapacity(p._marketId);
        uint256 maxShortCapacity = positionVault.maxShortCapacity(p._marketId);

        require(
            poolAmount >= reserveAmount + p._sizeAbs,
            "OrderValidator: Not enough token pool amount"
        );

        uint256 totalSize = p._isLong
            ? globalState.getGlobalLongPositionState(p._marketId).totalSize
            : globalState.getGlobalShortPositionState(p._marketId).totalSize;

        if (p._isLong) {
            require(
                maxLongCapacity >= totalSize + p._sizeAbs,
                "OrderValidator: Exceeds max long capacity"
            );
        } else {
            require(
                maxShortCapacity >= totalSize + p._sizeAbs,
                "OrderValidator: Exceeds max short capacity"
            );
        }
    }

    function validateDecreaseExecution(
        OrderParams calldata p,
        bytes32 _key // uint256 _markPrice
    ) external view {
        OpenPosition memory position = positionVault.getPosition(_key);

        require(
            position.size >= p._sizeAbs,
            "OrderValidator: Not enough position size"
        );
        require(
            position.margin >= p._marginAbs,
            "OrderValidator: Not enough margin size"
        );
    }
}
