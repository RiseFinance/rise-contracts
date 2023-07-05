// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract L3Vault {
    struct UserVault {
        uint256 balance;
        bytes32 versionHash;
    }

    struct Order {
        bool isLong;
        bool isMarketOrder;
        uint8 orderType; // open=0, increase=1, decrease=2, close=3, liquidate=4
        uint256 size;
        uint256 markPrice;
        uint256 assetId;
        // value change 등 추가
    }

    struct GlobalPositionState {
        bool isLong;
        uint256 totalSize;
        uint256 totalCollateral;
        uint256 averagePrice;
    }

    struct Position {
        uint256 size;
        uint256 collateral;
        uint256 averagePrice;
        uint256 reserveAmount;
        int256 realizedPnl;
        uint256 lastUpdatedTime;
    }

    // mapping to MerkleTree
    mapping(address => mapping(uint256 => UserVault)) public traderBalances; // userKey => assetId => UserVault
    mapping(address => mapping(uint256 => Order)) public traderOrders; // userKey => orderId => Order

    mapping(uint256 => uint256) public tokenPoolAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public tokenReserveAmounts; // assetId => tokenCount

    mapping(uint256 => GlobalPositionState) public globalLongStates;
    mapping(uint256 => GlobalPositionState) public globalShortStates;

    mapping(bytes32 => Position) public positions; // positionHash => Position
}
