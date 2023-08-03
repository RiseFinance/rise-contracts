// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./enums.sol";

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
