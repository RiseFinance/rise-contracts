// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol"; // test-only
import "./interfaces/IPriceManager.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ArbSys.sol";

contract L3Vault {
    // ---------------------------------------------------- States ----------------------------------------------------
    IPriceManager public priceManager;

    uint256 public constant usdDecimals = 8;
    uint256 public constant USD_ID = 0;
    uint256 public constant ETH_ID = 1;
    uint256 private constant assetIdCounter = 1; // temporary
    mapping(uint256 => uint256) public tokenDecimals; // TODO: listing restriction needed

    struct OrderContext {
        uint256 _indexAssetId;
        uint256 _collateralAssetId;
        bool _isLong;
        bool _isIncrease;
        uint256 _size; // in token amounts
        uint256 _collateralSize; // in token amounts
    }

    struct OrderRequest {
        uint256 indexAssetId;
        uint256 collateralAssetId;
        bool isLong;
        bool isIncrease;
        uint256 sizeDeltaAbs;
    }

    struct FilledOrder {
        uint256 indexAssetId;
        uint256 collateralAssetId;
        bool isLong;
        bool isIncrease;
        uint256 sizeDeltaAbs;
        uint256 collateralSizeDeltaAbs;
        bool isMarketOrder;
        uint256 markPrice;
    }

    struct Position {
        uint256 size;
        uint256 collateralSizeInUsd;
        uint256 avgOpenPrice; // TODO: check - should be coupled w/ positions link logic
        uint256 lastUpdatedTime;
    }

    struct GlobalPositionState {
        uint256 totalSize;
        uint256 totalCollateral;
        uint256 avgPrice;
    }

    mapping(address => mapping(uint256 => uint256)) public traderBalances; // userAddress => assetId => Balance
    mapping(address => uint256) public traderFilledOrderCounts; // userAddress => orderCount

    mapping(address => mapping(uint256 => FilledOrder)) public filledOrders; // userAddress => traderOrderCount => Order (filled orders by trader)
    mapping(address => mapping(uint256 => OrderRequest)) public pendingOrders; // userAddress => pendingId => Order (pending orders by trader)

    mapping(uint256 => mapping(uint256 => OrderRequest[])) public buyOrderBook; // indexAssetId => price => Order[] (Global Queue)
    mapping(uint256 => mapping(uint256 => OrderRequest[])) public sellOrderBook; // indexAssetId => price => Order[] (Global Queue)

    mapping(uint256 => uint256) public balancesTracker; // assetId => balance; only used in _depositInAmount
    mapping(uint256 => uint256) public tokenPoolAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public tokenReserveAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public maxLongCapacity; // assetId => tokenCount
    mapping(uint256 => uint256) public maxShortCapacity; // assetId => tokenCount // TODO: check - is it for stablecoins?

    mapping(bool => mapping(uint256 => GlobalPositionState))
        public globalPositionState; // assetId => GlobalPositionState

    // TODO: open <> close 사이의 position을 하나로 연결하여 기록
    mapping(bytes32 => Position) public positions; // positionHash => Position

    // ------------------------------------------------- Constructor --------------------------------------------------

    constructor(address _priceManager) {
        priceManager = IPriceManager(_priceManager);
    }

    // ------------------------------------------------ Util Functions ------------------------------------------------

    function _getPositionKey(
        address _account,
        bool _isLong,
        uint256 _indexAssetId,
        uint256 _collateralAssetId
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _account,
                    _isLong,
                    _indexAssetId,
                    _collateralAssetId
                )
            );
    }

    function _getMarkPrice(
        uint256 _assetId,
        uint256 _size,
        bool _isLong
    ) internal returns (uint256) {
        /**
         *
         * @dev Jae Yoon
         */
        return priceManager.getAverageExecutionPrice(_assetId, _size, _isLong);
    }

    // TODO: check - for short positions, should we use collateralAsset for tracking position size?
    function _updateGlobalPositionState(
        bool _isLong,
        bool _isIncrease,
        uint256 _indexAssetId,
        uint256 _sizeDelta,
        uint256 _collateralDelta,
        uint256 _markPrice
    ) internal {
        globalPositionState[_isLong][_indexAssetId].avgPrice = _getNewAvgPrice(
            _isIncrease,
            globalPositionState[_isLong][_indexAssetId].totalSize,
            globalPositionState[_isLong][_indexAssetId].avgPrice,
            _sizeDelta,
            _markPrice
        );

        if (_isIncrease) {
            globalPositionState[_isLong][_indexAssetId].totalSize += _sizeDelta;
            globalPositionState[_isLong][_indexAssetId]
                .totalCollateral += _collateralDelta;
        } else {
            globalPositionState[_isLong][_indexAssetId].totalSize -= _sizeDelta;
            globalPositionState[_isLong][_indexAssetId]
                .totalCollateral -= _collateralDelta;
        }
    }

    /**
     * (new avg price) * (new size) = (old avg price) * (old size) + (mark price) * (size delta)
     * */
    function _getNewAvgPrice(
        bool _isIncrease,
        uint256 _oldSize,
        uint256 _oldAvgPrice,
        uint256 _sizeDelta,
        uint256 _markPrice
    ) internal pure returns (uint256) {
        if (_isIncrease) {
            uint256 newSize = _oldSize + _sizeDelta;
            uint256 newAvgPrice = newSize == 0
                ? 0
                : (_oldAvgPrice * _oldSize + _markPrice * _sizeDelta) / newSize;
            return newAvgPrice;
        } else {
            // TODO: check - this logic needed?
            uint256 newSize = _oldSize - _sizeDelta;
            uint256 newAvgPrice = newSize == 0
                ? 0
                : (_oldAvgPrice * _oldSize - _markPrice * _sizeDelta) / newSize;
            return newAvgPrice;
        }
    }

    function _usdToToken(
        uint256 _usdAmount,
        uint256 _tokenPrice,
        uint256 _tokenDecimals
    ) internal pure returns (uint256) {
        return
            ((_usdAmount * 10 ** _tokenDecimals) / 10 ** usdDecimals) /
            _tokenPrice;
    }

    function _tokenToUsd(
        uint256 _tokenAmount,
        uint256 _tokenPrice,
        uint256 _tokenDecimals
    ) internal pure returns (uint256) {
        return
            ((_tokenAmount * _tokenPrice) * 10 ** usdDecimals) /
            10 ** _tokenDecimals;
    }

    function _calculatePnL(
        uint256 _size,
        uint256 _averagePrice,
        uint256 _markPrice,
        bool _isLong
    ) internal pure returns (uint256, bool) {
        uint256 pnlAbs = _markPrice >= _averagePrice
            ? (_size * (_markPrice - _averagePrice)) / 10 ** 18
            : (_size * (_averagePrice - _markPrice)) / 10 ** 18;
        bool hasProfit = _markPrice >= _averagePrice ? _isLong : !_isLong;
        return (pnlAbs, hasProfit);
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

    // --------------------------------------------- Validation Functions ---------------------------------------------

    function _isAssetIdValid(uint256 _assetId) internal pure returns (bool) {
        // TODO: deal with delisting assets
        return _assetId < assetIdCounter;
    }

    function _validateOrder(OrderContext memory c) internal view {
        require(msg.sender != address(0), "L3Vault: Invalid sender address");
        require(
            msg.sender == tx.origin,
            "L3Vault: Invalid sender address (contract)"
        );
        require(
            _isAssetIdValid(c._indexAssetId),
            "L3Vault: Invalid index asset id"
        );
        require(
            traderBalances[msg.sender][c._collateralAssetId] >=
                c._collateralSize,
            "L3Vault: Not enough balance"
        );
        require(c._size >= 0, "L3Vault: Invalid size");
        require(c._collateralSize >= 0, "L3Vault: Invalid collateral size");
    }

    function _validateIncreaseExecution(OrderContext memory c) internal view {
        require(
            tokenPoolAmounts[c._indexAssetId] >=
                tokenReserveAmounts[c._indexAssetId] + c._size,
            "L3Vault: Not enough token pool amount"
        );
        if (c._isLong) {
            require(
                maxLongCapacity[c._indexAssetId] >=
                    globalPositionState[true][c._indexAssetId].totalSize +
                        c._size,
                "L3Vault: Exceeds max long capacity"
            );
        } else {
            require(
                maxShortCapacity[c._indexAssetId] >=
                    globalPositionState[false][c._indexAssetId].totalSize +
                        c._size,
                "L3Vault: Exceeds max short capacity"
            );
        }
    }

    function _validateDecreaseExecution(
        OrderContext memory c,
        bytes32 _key,
        uint256 _markPrice
    ) internal view {
        require(
            positions[_key].size >= c._size,
            "L3Vault: Not enough position size"
        );
        require(
            positions[_key].collateralSizeInUsd >=
                _tokenToUsd(
                    c._collateralSize,
                    _markPrice,
                    tokenDecimals[c._collateralAssetId]
                ),
            "L3Vault: Not enough collateral size"
        );
    }

    // ----------------------------------------------- Order Functions ------------------------------------------------

    function placeMarketOrder(
        OrderContext memory c
    ) external returns (bytes32) {
        _validateOrder(c);

        bytes32 key = _getPositionKey(
            msg.sender,
            c._isLong,
            c._indexAssetId,
            c._collateralAssetId
        );

        // get markprice
        bool _isBuy = c._isLong == c._isIncrease;
        uint256 markPrice = _getMarkPrice(c._indexAssetId, c._size, _isBuy); // TODO: check - to put after validations?

        if (c._isIncrease) {
            increasePosition(c, key, markPrice);
        } else {
            // decreasePosition(c, key, markPrice);
        }

        return key;
    }

    function increasePosition(
        OrderContext memory c,
        bytes32 _key,
        uint256 _markPrice
    ) internal {
        // validation
        _validateIncreaseExecution(c);

        // update state variables
        traderBalances[msg.sender][c._collateralAssetId] -= c._collateralSize;
        tokenReserveAmounts[c._indexAssetId] += c._size;

        // fill the order
        filledOrders[msg.sender][
            traderFilledOrderCounts[msg.sender]
        ] = FilledOrder(
            c._indexAssetId,
            c._collateralAssetId,
            c._isLong,
            c._isIncrease,
            c._size,
            c._collateralSize,
            true,
            _markPrice
        );
        traderFilledOrderCounts[msg.sender] += 1;

        // update position
        Position storage position = positions[_key];
        position.avgOpenPrice = _getNewAvgPrice(
            true,
            position.size,
            position.avgOpenPrice,
            c._size,
            _markPrice
        );
        position.size += c._size;
        position.collateralSizeInUsd += _tokenToUsd(
            c._collateralSize,
            _markPrice,
            tokenDecimals[c._collateralAssetId]
        );
        position.lastUpdatedTime = block.timestamp;

        // update global position state
        _updateGlobalPositionState(
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._size,
            c._collateralSize,
            _markPrice
        );
    }

    function decreasePosition(
        OrderContext memory c,
        bytes32 _key,
        uint256 _markPrice
    ) internal {
        // validation
        _validateDecreaseExecution(c, _key, _markPrice);

        // update state variables
        Position storage position = positions[_key];
        (uint256 pnlUsdAbs, bool isPositive) = _calculatePnL(
            position.size,
            position.avgOpenPrice,
            _markPrice,
            c._isLong
        );

        uint256 traderBalance = traderBalances[msg.sender][
            c._collateralAssetId
        ];

        traderBalance += c._collateralSize; // c._collateralSize calculated before this point by the amount of decrease
        traderBalance = isPositive
            ? traderBalance + pnlUsdAbs // FIXME: USD or token?
            : traderBalance - pnlUsdAbs;
        // TODO: check - PnL includes collateral?

        // TODO: settlement in USD or tokens?
        tokenPoolAmounts[USD_ID] = isPositive
            ? tokenPoolAmounts[USD_ID] - pnlUsdAbs // add validation here for not going below 0 or allow & swap tokens => USD by system call
            : tokenPoolAmounts[USD_ID] + pnlUsdAbs;

        tokenReserveAmounts[c._indexAssetId] -= c._size;

        // fill the order
        filledOrders[msg.sender][
            traderFilledOrderCounts[msg.sender]
        ] = FilledOrder(
            c._indexAssetId,
            c._collateralAssetId,
            c._isLong,
            c._isIncrease,
            c._size,
            c._collateralSize,
            true,
            _markPrice
        );
        traderFilledOrderCounts[msg.sender] += 1;

        // update position
        // if close position
        if (c._size == position.size) {
            delete positions[_key];
        } else {
            // position.avgOpenPrice = _getNewAvgPrice(
            //     false,
            //     position.size,
            //     position.avgOpenPrice,
            //     c._size,
            //     _markPrice
            // );
            position.size -= c._size;
            position.collateralSizeInUsd -= _tokenToUsd(
                c._collateralSize,
                _markPrice,
                tokenDecimals[c._collateralAssetId]
            );
            position.lastUpdatedTime = block.timestamp;
        }

        // update global position state
        _updateGlobalPositionState(
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._size,
            c._collateralSize,
            _markPrice
        );
    }

    // ----------------------------------------- Deposit & Withdraw Functions -----------------------------------------
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
    // ---------------------------------------------------- Events ----------------------------------------------------
}
