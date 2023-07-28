// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract Structs {
    struct OrderContext {
        bool _isLong;
        bool _isIncrease;
        uint256 _marketId;
        uint256 _sizeAbs; // Token Counts
        uint256 _marginAbs; // Token Counts
        uint256 _limitPrice; // empty for market orders
    } // TODO: modify - size in Token Counts

    // limit
    struct OrderRequest {
        address trader;
        bool isLong;
        bool isIncrease;
        uint256 marketId;
        uint256 sizeAbs;
        uint256 marginAbs;
        uint256 limitPrice;
    }

    // limit, market
    struct FilledOrder {
        bool isMarketOrder;
        bool isLong;
        bool isIncrease;
        uint256 marketId;
        uint256 sizeAbs;
        uint256 marginAbs;
        uint256 executionPrice;
    }

    struct Position {
        uint256 size; // Token Counts
        uint256 margin; // Token Counts
        uint256 avgOpenPrice; // TODO: check - should be coupled w/ positions link logic
        uint256 lastUpdatedTime; // Currently not used for any validation
    }

    struct GlobalPositionState {
        uint256 totalSize;
        uint256 totalMargin;
        uint256 avgPrice;
    }
}
