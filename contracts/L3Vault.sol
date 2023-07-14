// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol"; // test-only
import "./interfaces/IPriceManager.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ArbSys.sol";
import "./CommonContext.sol";

contract L3Vault is CommonContext {
    // ---------------------------------------------------- States ----------------------------------------------------
    IPriceManager public priceManager;

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

    // ------------------------------------------------- Constructor --------------------------------------------------

    constructor(address _priceManager) {
        priceManager = IPriceManager(_priceManager);
    }

    function getMarkPrice(
        uint256 _assetId,
        uint256 _size,
        bool _isLong
    ) internal returns (uint256) {
        /**
         * // TODO: impl
         * @dev Jae Yoon
         */
        return priceManager.getAverageExecutionPrice(_assetId, _size, _isLong);
    }

    // ---------------------------------------------- Primary Functions -----------------------------------------------

    // function _increasePoolAmounts(uint256 assetId, uint256 _amount) internal {
    //     tokenPoolAmounts[assetId] += _amount;
    // }

    // function _decreasePoolAmounts(uint256 assetId, uint256 _amount) internal {
    //     require(
    //         tokenPoolAmounts[assetId] >= _amount,
    //         "L3Vault: Not enough token pool _amount"
    //     );
    //     tokenPoolAmounts[assetId] -= _amount;
    // }

    function increaseTraderBalance(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) public {
        traderBalances[_trader][_assetId] += _amount;
    }

    function decreaseTraderBalance(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) public {
        traderBalances[_trader][_assetId] -= _amount;
    }

    function getTraderBalance(
        address _trader,
        uint256 _assetId
    ) external view returns (uint256) {
        return traderBalances[_trader][_assetId];
    }

    function _increaseReserveAmounts(
        uint256 assetId,
        uint256 _amount
    ) internal {
        require(
            tokenPoolAmounts[assetId] >= tokenReserveAmounts[assetId] + _amount,
            "L3Vault: Not enough token pool amount"
        );
        tokenReserveAmounts[assetId] += _amount;
    }

    function _decreaseReserveAmounts(
        uint256 assetId,
        uint256 _amount
    ) internal {
        require(
            tokenReserveAmounts[assetId] >= _amount,
            "L3Vault: Not enough token reserve amount"
        );
        tokenReserveAmounts[assetId] -= _amount;
    }

    function getPositionSizeInUsd(bytes32 key) public view returns (uint256) {
        return positions[key].sizeInUsd;
    }

    function updatePosition(
        bytes32 _key,
        uint256 _markPrice,
        uint256 _sizeDeltaAbsInUsd,
        uint256 _collateralDeltaAbsInUsd,
        bool _isIncreaseInSize,
        bool _isIncreaseInCollateral
    ) public {
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

    function deletePosition(bytes32 _key) public {
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
    ) public {
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
    ) public {
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
    ) public {
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

    function _validateIncreaseExecution(OrderContext calldata c) internal view {
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

    function _validateDecreaseExecution(
        OrderContext calldata c,
        bytes32 _key,
        uint256 _markPrice
    ) internal view {
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

    function increasePosition(
        OrderContext calldata c,
        bool _isBuy // TODO: change name into executionPrice? => Price Impact 적용된 상태?
    ) external returns (bytes32) {
        // validations
        _validateIncreaseExecution(c);

        // update state variables

        uint256 markPrice = getMarkPrice(
            c._indexAssetId,
            c._sizeAbsInUsd,
            _isBuy
        );

        traderBalances[msg.sender][c._collateralAssetId] -= c
            ._collateralAbsInUsd;
        tokenReserveAmounts[c._indexAssetId] += c._sizeAbsInUsd;

        // fill the order
        fillOrder(
            msg.sender,
            true, // isMarketOrder
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._collateralAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            markPrice
        );

        // update position
        bytes32 key = _getPositionKey(
            msg.sender,
            c._isLong,
            c._indexAssetId,
            c._collateralAssetId
        );

        updatePosition(
            key,
            markPrice,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            true, // isIncreaseInSize
            true // isIncreaseInCollateral
        );

        // update global position state
        updateGlobalPositionState(
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            markPrice
        );

        return key;
    }

    function decreasePosition(
        OrderContext calldata c,
        bool _isBuy
    ) external returns (bytes32) {
        // validations

        uint256 markPrice = getMarkPrice(
            c._indexAssetId,
            c._sizeAbsInUsd,
            _isBuy
        );

        bytes32 key = _getPositionKey(
            msg.sender,
            c._isLong,
            c._indexAssetId,
            c._collateralAssetId
        );
        _validateDecreaseExecution(c, key, markPrice);

        settlePnL(
            key,
            c._isLong,
            markPrice,
            c._indexAssetId,
            c._collateralAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd
        );

        // fill the order
        fillOrder(
            msg.sender,
            true, // isMarketOrder
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._collateralAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            markPrice
        );

        uint256 positionSizeInUsd = getPositionSizeInUsd(key);

        if (c._sizeAbsInUsd == positionSizeInUsd) {
            // close position
            deletePosition(key);
        } else {
            // partial close position
            updatePosition(
                key,
                markPrice,
                c._sizeAbsInUsd,
                c._collateralAbsInUsd,
                false, // isIncreaseInSize
                false // isIncreaseInCollateral
            );
        }

        // update global position state
        updateGlobalPositionState(
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            markPrice
        );

        return key;
    }

    // ------------------------------------------- Liquidity Pool Functions -------------------------------------------
    function addLiquidity(uint256 assetId, uint256 amount) external payable {
        require(msg.value >= amount, "L3Vault: insufficient amount");
        // TODO: check - how to mint the LP token?
        tokenPoolAmounts[assetId] += amount;
        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        } // refund
    }

    function removeLiquidity(uint256 assetId, uint256 amount) external {
        tokenPoolAmounts[assetId] -= amount;
        payable(msg.sender).transfer(amount);
    }
}
// ---------------------------------------------------- Events ----------------------------------------------------
