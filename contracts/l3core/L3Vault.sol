// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol"; // test-only
import "../interfaces/l3/IL3Vault.sol";
import "../interfaces/l3/IERC20.sol";
import "../interfaces/l3/ArbSys.sol";
import "./common/Context.sol";

// TODO: check - `override` needed for function declared in the interface `IL3Vault`?
contract L3Vault is IL3Vault, Context {
    // ---------------------------------------------------- States ----------------------------------------------------

    uint256 private constant assetIdCounter = 1; // temporary
    mapping(uint256 => uint256) public tokenDecimals; // TODO: listing restriction needed

    mapping(address => mapping(uint256 => uint256)) public traderBalances; // userAddress => assetId => Balance
    mapping(address => uint256) public traderFilledOrderCounts; // userAddress => orderCount

    mapping(address => mapping(uint256 => FilledOrder)) public filledOrders; // userAddress => traderOrderCount => Order (filled orders by trader)

    mapping(uint256 => uint256) public tokenPoolAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public tokenReserveAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public maxLongCapacity; // assetId => tokenCount
    mapping(uint256 => uint256) public maxShortCapacity; // assetId => tokenCount // TODO: check - is it for stablecoins?
    mapping(bool => mapping(uint256 => GlobalPositionState))
        public globalPositionStates; // assetId => GlobalPositionState

    // TODO: open <> close 사이의 position을 하나로 연결하여 기록
    mapping(bytes32 => Position) public positions; // positionHash => Position

    // ---------------------------------------------- Primary Functions -----------------------------------------------

    function _increasePoolAmounts(uint256 assetId, uint256 _amount) internal {
        tokenPoolAmounts[assetId] += _amount;
    }

    function _decreasePoolAmounts(uint256 assetId, uint256 _amount) internal {
        require(
            tokenPoolAmounts[assetId] >= _amount,
            "L3Vault: Not enough token pool _amount"
        );
        tokenPoolAmounts[assetId] -= _amount;
    }

    function increaseTraderBalance(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) external {
        traderBalances[_trader][_assetId] += _amount;
    }

    function decreaseTraderBalance(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) external {
        traderBalances[_trader][_assetId] -= _amount;
    }

    function getTraderBalance(
        address _trader,
        uint256 _assetId
    ) external view returns (uint256) {
        return traderBalances[_trader][_assetId];
    }

    function increaseReserveAmounts(uint256 assetId, uint256 _amount) external {
        require(
            tokenPoolAmounts[assetId] >= tokenReserveAmounts[assetId] + _amount,
            "L3Vault: Not enough token pool amount"
        );
        tokenReserveAmounts[assetId] += _amount;
    }

    function decreaseReserveAmounts(uint256 assetId, uint256 _amount) external {
        require(
            tokenReserveAmounts[assetId] >= _amount,
            "L3Vault: Not enough token reserve amount"
        );
        tokenReserveAmounts[assetId] -= _amount;
    }

    function getPositionSizeInUsd(bytes32 key) external view returns (uint256) {
        return positions[key].sizeInUsd;
    }

    function updatePosition(
        bytes32 _key,
        uint256 _markPrice,
        uint256 _sizeDeltaAbsInUsd,
        uint256 _collateralDeltaAbsInUsd,
        bool _isIncreaseInSize,
        bool _isIncreaseInCollateral
    ) external {
        Position storage _position = positions[_key];
        if (_sizeDeltaAbsInUsd > 0 && _isIncreaseInSize) {
            _position.avgOpenPrice = _getNextAvgPrice(
                _isIncreaseInSize,
                _position.sizeInUsd,
                _position.avgOpenPrice,
                _sizeDeltaAbsInUsd,
                _markPrice
            );
        }
        _position.sizeInUsd = _isIncreaseInSize
            ? _position.sizeInUsd + _sizeDeltaAbsInUsd
            : _position.sizeInUsd - _sizeDeltaAbsInUsd;

        _position.collateralInUsd = _isIncreaseInCollateral
            ? _position.collateralInUsd + _collateralDeltaAbsInUsd
            : _position.collateralInUsd - _collateralDeltaAbsInUsd;

        _position.lastUpdatedTime = block.timestamp;
    }

    function deletePosition(bytes32 _key) external {
        delete positions[_key];
    }

    function fillOrder(
        address _trader,
        bool _isMarketOrder,
        bool _isLong,
        bool _isIncrease,
        uint256 _indexAssetId,
        uint256 _collateralAssetId,
        uint256 _sizeAbsInUsd,
        uint256 _collateralAbsInUsd,
        uint256 _executionPrice
    ) external {
        filledOrders[_trader][traderFilledOrderCounts[_trader]] = FilledOrder(
            _isMarketOrder,
            _isLong,
            _isIncrease,
            _indexAssetId,
            _collateralAssetId,
            _sizeAbsInUsd,
            _collateralAbsInUsd,
            _executionPrice
        );
        traderFilledOrderCounts[_trader]++;
    }

    function settlePnL(
        bytes32 _key,
        bool _isLong,
        uint256 _markPrice,
        uint256 _indexAssetId,
        uint256 _collateralAssetId,
        uint256 _sizeAbsInUsd,
        uint256 _collateralAbsInUsd
    ) external {
        Position memory position = positions[_key];
        (uint256 pnlUsdAbs, bool traderHasProfit) = _calculatePnL(
            position.sizeInUsd,
            position.avgOpenPrice,
            _markPrice,
            _isLong
        );

        traderBalances[msg.sender][_collateralAssetId] += _collateralAbsInUsd;
        traderBalances[msg.sender][_collateralAssetId] = traderHasProfit
            ? traderBalances[msg.sender][_collateralAssetId] + pnlUsdAbs
            : traderBalances[msg.sender][_collateralAssetId] - pnlUsdAbs;
        // TODO: check - PnL includes collateral?

        tokenPoolAmounts[USD_ID] = traderHasProfit // TODO: check- settlement in USD or in tokens?
            ? tokenPoolAmounts[USD_ID] - pnlUsdAbs
            : tokenPoolAmounts[USD_ID] + pnlUsdAbs;

        tokenReserveAmounts[_indexAssetId] -= _sizeAbsInUsd;
    }

    // TODO: check - for short positions, should we use collateralAsset for tracking position size?
    function updateGlobalPositionState(
        bool _isLong,
        bool _isIncrease,
        uint256 _indexAssetId,
        uint256 _sizeDelta,
        uint256 _collateralDelta,
        uint256 _markPrice
    ) external {
        globalPositionStates[_isLong][_indexAssetId]
            .avgPrice = _getNextAvgPrice(
            _isIncrease,
            globalPositionStates[_isLong][_indexAssetId].totalSizeInUsd,
            globalPositionStates[_isLong][_indexAssetId].avgPrice,
            _sizeDelta,
            _markPrice
        );

        if (_isIncrease) {
            globalPositionStates[_isLong][_indexAssetId]
                .totalSizeInUsd += _sizeDelta;
            globalPositionStates[_isLong][_indexAssetId]
                .totalCollateralInUsd += _collateralDelta;
        } else {
            globalPositionStates[_isLong][_indexAssetId]
                .totalSizeInUsd -= _sizeDelta;
            globalPositionStates[_isLong][_indexAssetId]
                .totalCollateralInUsd -= _collateralDelta;
        }
    }

    // --------------------------------------------- Validation Functions ---------------------------------------------

    function isAssetIdValid(uint256 _assetId) external pure returns (bool) {
        // TODO: deal with delisting assets
        return _assetId < assetIdCounter;
    }

    function validateIncreaseExecution(OrderContext calldata c) external view {
        require(
            tokenPoolAmounts[c._indexAssetId] >=
                tokenReserveAmounts[c._indexAssetId] + c._sizeAbsInUsd,
            "L3Vault: Not enough token pool amount"
        );
        if (c._isLong) {
            require(
                maxLongCapacity[c._indexAssetId] >=
                    globalPositionStates[true][c._indexAssetId].totalSizeInUsd +
                        c._sizeAbsInUsd,
                "L3Vault: Exceeds max long capacity"
            );
        } else {
            require(
                maxShortCapacity[c._indexAssetId] >=
                    globalPositionStates[false][c._indexAssetId]
                        .totalSizeInUsd +
                        c._sizeAbsInUsd,
                "L3Vault: Exceeds max short capacity"
            );
        }
    }

    function validateDecreaseExecution(
        OrderContext calldata c,
        bytes32 _key,
        uint256 _markPrice
    ) external view {
        require(
            positions[_key].sizeInUsd >= c._sizeAbsInUsd,
            "L3Vault: Not enough position size"
        );
        require(
            positions[_key].collateralInUsd >=
                _tokenToUsd(
                    c._collateralAbsInUsd,
                    _markPrice,
                    tokenDecimals[c._collateralAssetId]
                ),
            "L3Vault: Not enough collateral size"
        );
    }

    // ------------------------------------------- Liquidity Pool Functions -------------------------------------------

    /**
     * @notice to be deprecated
     */
    function addLiquidityWithTokensTransfer(
        uint256 assetId,
        uint256 amount
    ) external payable {
        require(msg.value >= amount, "L3Vault: insufficient amount");
        // TODO: check - how to mint the LP token?
        tokenPoolAmounts[assetId] += amount;
        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        } // refund
    }

    /**
     * @notice to be deprecated
     */
    function removeLiquidityWithTokensTransfer(
        uint256 assetId,
        uint256 amount
    ) external {
        tokenPoolAmounts[assetId] -= amount;
        payable(msg.sender).transfer(amount);
    }

    // TODO: check how to determine the Liquidity Provider
    function addLiquidity(uint256 assetId, uint256 amount) external {
        _increasePoolAmounts(assetId, amount);
    }

    function removeLiquidity(uint256 assetId, uint256 amount) external {
        _decreasePoolAmounts(assetId, amount);
    }
}
// ---------------------------------------------------- Events ----------------------------------------------------
