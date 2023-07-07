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

    event DepositEth(address indexed user, uint256 amount);

    event OpenPosition(
        bytes32 positionKey,
        address indexed user,
        uint256 collateralAssetId,
        uint256 indexAssetId,
        uint256 size,
        uint256 collateralSize,
        bool isLong,
        uint256 openPrice
    );

    event ClosePosition(
        bytes32 positionKey,
        address indexed user,
        uint256 collateralAssetId,
        uint256 indexAssetId,
        uint256 size,
        uint256 collateralSize,
        bool isLong,
        uint256 closePrice,
        uint256 realizedPnlAbs,
        bool isPositive
    );

    // mapping to MerkleTree
    IPriceFeed public priceFeed;
    mapping(address => mapping(uint256 => UserVault)) public traderBalances; // userKey => assetId => UserVault
    mapping(address => mapping(uint256 => Order)) public traderOrders; // userKey => orderId => Order

    mapping(uint256 => uint256) public tokenPoolAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public tokenReserveAmounts; // assetId => tokenCount

    mapping(uint256 => GlobalPositionState) public globalLongStates;
    mapping(uint256 => GlobalPositionState) public globalShortStates;

    mapping(bytes32 => Position) public positions; // positionHash => Position

    constructor(address _priceFeed) {
        priceFeed = IPriceFeed(_priceFeed);
    }

    // What if the trader requests two different orders with the same index Asset?
    // => The second order should be 'Increase Position', being integrated with the first order.
    function _getPositionKey(
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

    function depositEth() external payable {
        require(msg.value > 0, "L3Vault: deposit amount should be positive");
        UserVault storage userEthVault = traderBalances[msg.sender][1];
        userEthVault.balance += msg.value;
        bytes32 prevVersionHash = userEthVault.versionHash;
        userEthVault.versionHash = keccak256(
            abi.encodePacked(prevVersionHash, msg.value)
        );

        emit DepositEth(msg.sender, msg.value);
    }

    // open Position (market order)
    function openPosition(
        address _account,
        uint256 _collateralAssetId,
        uint256 _indexAssetId,
        uint256 _size,
        uint256 _collateralSize,
        bool _isLong
    ) external returns (bytes32) {
        // Create Order & Update Position
        require(_size > 0, "L3Vault: size should be positive");
        require(
            _collateralSize > 0,
            "L3Vault: collateralSize should be positive"
        );
        require(
            tokenPoolAmounts[_indexAssetId] >= _size,
            "L3Vault: insufficient token pool amount"
        );

        bytes32 key = _getPositionKey(
            _account,
            _collateralAssetId,
            _indexAssetId,
            _isLong
        );

        Position storage position = positions[key];

        require(position.size == 0, "L3Vault: position already exists");
        uint256 markPrice = getMarkPrice(_indexAssetId);

        // update position fields
        position.size = _size;
        position.collateralSize = _collateralSize;
        position.averagePrice = markPrice;
        position.realizedPnl = 0;
        position.lastUpdatedTime = block.timestamp;

        // update GlobalPositionState
        // update UserVault
        UserVault storage userVault = traderBalances[_account][_indexAssetId];

        require(
            userVault.balance >= _collateralSize,
            "L3Vault: insufficient balance"
        );

        userVault.balance -= _collateralSize; // TODO: 여기 로직

        // update tokenPoolAmounts
        // tokenPoolAmounts[_collateralAssetId] += _collateralSize;
        // tokenPoolAmounts[_indexAssetId] -= _size; // => reserve 기록하므로, 따로 차감하지 않음

        // update tokenReserveAmounts
        tokenReserveAmounts[_indexAssetId] += _size;

        emit OpenPosition(
            key,
            _account,
            _collateralAssetId,
            _indexAssetId,
            _size,
            _collateralSize,
            _isLong,
            markPrice
        );

        // update traderOrders
        return key;
    }

    // close Position

    function closePosition(
        address _account,
        uint256 _collateralAssetId,
        uint256 _indexAssetId,
        bool _isLong
    ) external returns (bool) {
        bytes32 key = _getPositionKey(
            _account,
            _collateralAssetId,
            _indexAssetId,
            _isLong
        );
        Position storage position = positions[key];
        uint256 markPrice = getMarkPrice(_indexAssetId);
        uint256 collateralSize = position.collateralSize;
        // pnlAbs is in USD value
        (uint256 pnlAbs, bool isPositive) = _calculatePnL(
            position.size,
            position.averagePrice,
            markPrice,
            _isLong
        );
        // => (collateralSize + pnl) < 0이면, 이전애 liquidation 되어야 함
        // 청산 여부 검사 후 liquidation function call하고 종료

        // PnL 정산 (trader)
        UserVault storage userVault = traderBalances[_account][_indexAssetId];
        uint256 balanceDelta = isPositive
            ? (collateralSize + pnlAbs)
            : (collateralSize - pnlAbs);
        userVault.balance += balanceDelta;

        // PnL 정산 (token pool => 현재 USD value만큼 index 토큰 개수 차감)
        require(
            tokenPoolAmounts[_indexAssetId] >=
                _usdToToken(pnlAbs, markPrice, 18),
            "L3Vault: insufficient token pool amount"
        );
        tokenPoolAmounts[_indexAssetId] -= _usdToToken(
            balanceDelta,
            markPrice,
            18
        );

        // reserveAmount 줄이기
        require(
            tokenReserveAmounts[_indexAssetId] >= position.size,
            "L3Vault: token reserve amount is not enough"
        );
        tokenReserveAmounts[_indexAssetId] -= position.size;

        // delete position
        delete positions[key];

        emit ClosePosition(
            key,
            _account,
            _collateralAssetId,
            _indexAssetId,
            position.size,
            collateralSize,
            _isLong,
            markPrice,
            pnlAbs,
            isPositive
        );

        return true;
    }

    function _usdToToken(
        uint256 _usdAmount,
        uint256 _tokenPrice,
        uint256 _tokenDecimals
    ) internal pure returns (uint256) {
        return (_usdAmount * 10 ** _tokenDecimals) / _tokenPrice;
    }

    function _calculatePnL(
        uint256 _size,
        uint256 _averagePrice,
        uint256 _markPrice,
        bool _isLong
    ) internal pure returns (uint256, bool) {
        uint256 pnlAbs = _markPrice >= _averagePrice
            ? _size * (_markPrice - _averagePrice)
            : _size * (_averagePrice - _markPrice);
        bool hasProfit = _markPrice >= _averagePrice ? _isLong : !_isLong;
        return (pnlAbs, hasProfit);
    }

    // test-only
    function getPosition(bytes32 _key) external view returns (Position memory) {
        return positions[_key];
    }
}
