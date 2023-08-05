// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./enums.sol";

/// OrderRouter.sol (entrypoint)
struct OrderParams {
    bool _isLong;
    bool _isIncrease;
    uint256 _marketId;
    uint256 _sizeAbs; // Token Counts
    uint256 _marginAbs; // Token Counts
    uint256 _limitPrice; // empty for market orders
} // TODO: modify - size in Token Counts

/// PositionVault.sol (entrypoint)
struct UpdatePositionParams {
    OrderExecType _execType;
    bytes32 _key;
    bool _isOpening;
    address _trader;
    bool _isLong;
    uint256 _currentPositionRecordId;
    uint256 _marketId;
    uint256 _executionPrice;
    uint256 _sizeDeltaAbs;
    uint256 _marginDeltaAbs;
    bool _isIncreaseInSize;
    bool _isIncreaseInMargin;
}

/// L2LiquidityGateway.sol & L2MarginGateway.sol
struct L2ToL3FeeParams {
    uint256 _maxSubmissionCost;
    uint256 _gasLimit;
    uint256 _gasPriceBid;
}

/// PositionHistory.sol
struct OpenPositionRecordParams {
    address _trader;
    uint256 _marketId;
    uint256 _maxSize;
    uint256 _avgOpenPrice;
    uint256 _avgClosePrice;
}

struct UpdatePositionRecordParams {
    address _trader;
    bytes32 _key;
    uint256 _positionRecordId;
    bool _isIncrease;
    int256 _pnl;
    uint256 _sizeAbs;
    uint256 _avgExecPrice;
}

struct ClosePositionRecordParams {
    address _trader;
    uint256 _positionRecordId;
    int256 _pnl;
    uint256 _sizeAbs;
    uint256 _avgExecPrice;
}

/// OrderHistory.sol
struct CreateOrderRecordParams {
    address _trader;
    OrderType _orderType;
    bool _isLong;
    bool _isIncrease;
    uint256 _positionRecordId;
    uint256 _marketId;
    uint256 _sizeAbs;
    uint256 _marginAbs;
    uint256 _executionPrice;
}

/// GlobalState.sol
struct UpdateGlobalPositionStateParams {
    bool _isIncrease;
    uint256 _marketId;
    uint256 _sizeDeltaAbs;
    uint256 _marginDeltaAbs;
    uint256 _markPrice;
}
