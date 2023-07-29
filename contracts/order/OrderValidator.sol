// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../risepool/RisePool.sol";
import "../market/TokenInfo.sol";
import "../position/PositionVault.sol";
import "../global/GlobalState.sol";

contract OrderValidator {
    RisePool public risePool;
    TokenInfo public tokenInfo;
    PositionVault public positionVault;
    GlobalState public globalState;

    function validateIncreaseExecution(OrderContext calldata c) external view {
        uint256 poolAmount = c._isLong
            ? risePool.getLongPoolAmount(c._marketId)
            : risePool.getShortPoolAmount(c._marketId);

        uint256 reserveAmount = c._isLong
            ? risePool.getLongReserveAmount(c._marketId)
            : risePool.getShortReserveAmount(c._marketId);

        uint256 maxLongCapacity = positionVault.maxLongCapacity(c._marketId);
        uint256 maxShortCapacity = positionVault.maxShortCapacity(c._marketId);

        require(
            poolAmount >= reserveAmount + c._sizeAbs,
            "OrderValidator: Not enough token pool amount"
        );

        uint256 totalSize = c._isLong
            ? globalState.getGlobalLongPositionState(c._marketId).totalSize
            : globalState.getGlobalShortPositionState(c._marketId).totalSize;

        if (c._isLong) {
            require(
                maxLongCapacity >= totalSize + c._sizeAbs,
                "OrderValidator: Exceeds max long capacity"
            );
        } else {
            require(
                maxShortCapacity >= totalSize + c._sizeAbs,
                "OrderValidator: Exceeds max short capacity"
            );
        }
    }

    function validateDecreaseExecution(
        OrderContext calldata c,
        bytes32 _key // uint256 _markPrice
    ) external view {
        Position memory position = positionVault.getPosition(_key);

        require(
            position.size >= c._sizeAbs,
            "OrderValidator: Not enough position size"
        );
        require(
            position.margin >= c._marginAbs,
            "OrderValidator: Not enough margin size"
        );
    }
}
