// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./enums.sol";

// TODO: move to params.sol
struct OrderContext {
    bool _isLong;
    bool _isIncrease;
    uint256 _marketId;
    uint256 _sizeAbs; // Token Counts
    uint256 _marginAbs; // Token Counts
    uint256 _limitPrice; // empty for market orders
} // TODO: modify - size in Token Counts

// Limit order only
struct OrderRequest {
    address trader;
    bool isLong;
    bool isIncrease;
    uint256 marketId;
    uint256 sizeAbs;
    uint256 marginAbs;
    uint256 limitPrice;
}

struct OrderRecord {
    OrderType orderType;
    bool isLong;
    bool isIncrease;
    uint256 positionRecordId;
    uint256 marketId;
    uint256 sizeAbs;
    uint256 marginAbs;
    uint256 executionPrice;
    uint256 timestamp;
}

struct PositionRecord {
    bool isClosed;
    int256 cumulativeRealizedPnl; // cumulative realized PnL => this value to be closingPnl for closed positions
    uint256 cumulativeClosedSize; // FIXME: 수정사항 반영
    uint256 marketId;
    uint256 maxSize; // max open interest
    uint256 avgOpenPrice;
    uint256 avgClosePrice; // updated for decreasing/closing the position
    uint256 openTimestamp;
    uint256 closeTimestamp; // only for closed positions
}

struct OpenPosition {
    address trader;
    bool isLong;
    int256 unrealizedPnl; // current unrealized PnL => FIXME: this value should be update in real-time
    uint256 currentPositionRecordId;
    uint256 marketId;
    uint256 size; // Token Counts
    uint256 margin; // Token Counts
    uint256 avgOpenPrice; // TODO: check - should be coupled w/ positions link logic
    uint256 lastUpdatedTime; // Currently not used for any validation
    int256 entryFundingIndex;
}

struct GlobalPositionState {
    uint256 totalSize;
    uint256 totalMargin;
    uint256 avgPrice;
}
