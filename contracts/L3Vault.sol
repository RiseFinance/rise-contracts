// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./interfaces/IPriceFeed.sol";

contract L3Vault {
    struct UserVault {
        bytes32 versionHash;
        uint256 balance;
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
        uint256 collateralSize;
        uint256 averagePrice;
        uint256 lastUpdatedTime;
        int256 realizedPnl;
    }

    // mapping to MerkleTree
    IPriceFeed public priceFeed;
    mapping(address => mapping(uint256 => UserVault)) public traderBalances; // userKey => assetId => UserVault
    mapping(address => mapping(uint256 => Order)) public traderOrders; // userKey => orderId => Order

    mapping(uint256 => uint256) public tokenPoolAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public tokenReserveAmounts; // assetId => tokenCount

    mapping(uint256 => GlobalPositionState) public globalLongStates;
    mapping(uint256 => GlobalPositionState) public globalShortStates;

    mapping(bytes32 => Position) public positions; // positionHash => Position

    function getPositionKey(
        address _account,
        uint256 _collateralAssetId,
        uint256 _indexAssetId,
        bool _isLong
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _account,
                    _collateralAssetId,
                    _indexAssetId,
                    _isLong
                )
            );
    }

    function getMarkPrice(uint256 assetId) internal view returns (uint256) {
        // to implement in customized ArbOS
        return priceFeed.getPrice(assetId);
    }

    // function getPoolAmount(uint256 assetId) public view returns (uint256) {
    //     return tokenPoolAmounts[assetId];
    // }

    function getReserveAmount(uint256 assetId) public view returns (uint256) {
        return tokenReserveAmounts[assetId];
    }

    function addLiquidity(uint256 assetId, uint256 amount) external {
        // liquidity 기록을 변수에 할지, LP 토큰을 발행할지 결정
        // 발행한다면 모든 settlement chain에? (e.g. Arbitrum, zkSync, etc.)
        tokenPoolAmounts[assetId] += amount;
    }

    function removeLiquidity(uint256 assetId, uint256 amount) external {
        tokenPoolAmounts[assetId] -= amount;
    }

    // open Position
    function openPosition(
        address _account,
        uint256 _collateralAssetId,
        uint256 _indexAssetId,
        uint256 _size,
        uint256 _collateralSize,
        bool _isLong
    ) external returns (bytes32) {
        // create Order
        // update Position
        bytes32 key = getPositionKey(
            _account,
            _collateralAssetId,
            _indexAssetId,
            _isLong
        );

        Position storage position = positions[key];

        require(position.size == 0, "L3Vault: position already exists");
        // uint256 markPrice = getMarkPrice(_indexAssetId);

        uint256 markPrice = 1962;

        // update position fields
        position.size = _size;
        position.collateralSize = _collateralSize;
        position.averagePrice = markPrice;
        position.realizedPnl = 0;
        position.lastUpdatedTime = block.timestamp;

        // update GlobalPositionState
        // update UserVault
        UserVault storage userVault = traderBalances[_account][_indexAssetId];

        // test-only
        userVault.balance += 2 * _collateralSize;

        require(
            userVault.balance >= _collateralSize,
            "L3Vault: insufficient balance"
        );

        userVault.balance -= _collateralSize; // TODO: 여기 로직

        // update tokenReserveAmounts
        tokenReserveAmounts[_indexAssetId] += _size;

        // update traderOrders
        return key;
    }

    // close Position

    // test-only
    function getPosition(bytes32 key) external view returns (Position memory) {
        return positions[key];
    }
}
