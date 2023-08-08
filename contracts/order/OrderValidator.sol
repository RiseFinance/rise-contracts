// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../position/PositionVault.sol";
import "../global/GlobalState.sol";
import "../risepool/RisePool.sol";

contract OrderValidator {
    PositionVault public positionVault;
    GlobalState public globalState;
    RisePool public risePool;

    constructor(
        address _positionVault,
        address _globalState,
        address _risePool
    ) {
        positionVault = PositionVault(_positionVault);
        globalState = GlobalState(_globalState);
        risePool = RisePool(_risePool);
    }

    function validateIncreaseExecution(
        OrderRequest calldata req
    ) external view {
        uint256 poolAmount = req.isLong
            ? risePool.getLongPoolAmount(req.marketId)
            : risePool.getShortPoolAmount(req.marketId);

        uint256 reserveAmount = req.isLong
            ? risePool.getLongReserveAmount(req.marketId)
            : risePool.getShortReserveAmount(req.marketId);

        uint256 maxLongCapacity = positionVault.maxLongCapacity(req.marketId);
        uint256 maxShortCapacity = positionVault.maxShortCapacity(req.marketId);

        require(
            poolAmount >= reserveAmount + req.sizeAbs,
            "OrderValidator: Not enough token pool amount"
        );

        uint256 totalSize = req.isLong
            ? globalState.getGlobalLongPositionState(req.marketId).totalSize
            : globalState.getGlobalShortPositionState(req.marketId).totalSize;

        if (req.isLong) {
            require(
                maxLongCapacity >= totalSize + req.sizeAbs,
                "OrderValidator: Exceeds max long capacity"
            );
        } else {
            require(
                maxShortCapacity >= totalSize + req.sizeAbs,
                "OrderValidator: Exceeds max short capacity"
            );
        }
    }

    function validateDecreaseExecution(
        OrderRequest calldata req,
        bytes32 _key // uint256 _markPrice
    ) external view {
        OpenPosition memory position = positionVault.getPosition(_key);

        require(
            position.size >= req.sizeAbs,
            "OrderValidator: Not enough position size"
        );
        require(
            position.margin >= req.marginAbs,
            "OrderValidator: Not enough margin size"
        );
    }
}
