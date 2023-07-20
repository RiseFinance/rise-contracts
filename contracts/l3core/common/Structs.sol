// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract Structs {
    // struct OrderContext {
    //     bool _isLong;
    //     bool _isIncrease;
    //     uint256 _indexAssetId;
    //     uint256 _collateralAssetId;
    //     uint256 _sizeAbsInUsd;
    //     uint256 _collateralAbsInUsd;
    //     uint256 _limitPrice; // empty for market orders
    // }

    // limit
    struct OrderRequest {
        address trader;
        bool isLong;
        bool isIncrease;
        uint256 indexAssetId; // redundant?
        uint256 collateralAssetId;
        uint256 sizeAbsInUsd;
        uint256 collateralAbsInUsd;
        uint256 limitPrice;
    }

    // limit, market
    struct FilledOrder {
        bool isMarketOrder;
        bool isLong;
        bool isIncrease;
        uint256 indexAssetId;
        uint256 collateralAssetId;
        uint256 sizeAbsInUsd;
        uint256 collateralAbsInUsd;
        uint256 executionPrice;
    }

    struct Position {
        uint256 sizeInUsd;
        uint256 collateralInUsd;
        uint256 avgOpenPrice; // TODO: check - should be coupled w/ positions link logic
        uint256 lastUpdatedTime; // Currently not used for any validation
    }

    struct GlobalPositionState {
        uint256 totalSizeInUsd;
        uint256 totalCollateralInUsd;
        uint256 avgPrice;
    }
}
