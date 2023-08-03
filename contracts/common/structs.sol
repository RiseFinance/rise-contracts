// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./enums.sol";

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
    bool hasProfit;
    bool isClosed;
    uint256 marketId;
    uint256 maxSize; // max open interest
    uint256 avgOpenPrice;
    uint256 avgClosePrice;
    uint256 closingPnL;
    uint256 openTimestamp;
    uint256 closeTimestamp;
}

struct OpenPosition {
    address trader;
    bool isLong;
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
