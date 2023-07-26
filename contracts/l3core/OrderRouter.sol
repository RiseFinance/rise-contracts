// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./common/Context.sol";
import "../interfaces/l3/IPriceManager.sol";
import "../interfaces/l3/ITraderVault.sol"; // TODO: change to Interface
import "../interfaces/l3/IOrderBook.sol";

// TODO: check - OrderRouter to inherit TraderVault?
contract OrderRouter is Context {
    ITraderVault traderVault;
    IOrderBook orderBook;
    IPriceManager priceManager;

    constructor(
        address _traderVault,
        address _orderBook,
        address _priceManager
    ) {
        traderVault = ITraderVault(_traderVault);
        orderBook = IOrderBook(_orderBook);
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

    function _validateOrder(
        ITraderVault.OrderContext calldata c
    ) internal view {
        require(
            msg.sender != address(0),
            "OrderRouter: Invalid sender address"
        );
        require(
            msg.sender == tx.origin,
            "OrderRouter: Invalid sender address (contract)"
        );
        require(
            traderVault.isAssetIdValid(c._indexAssetId),
            "OrderRouter: Invalid index asset id"
        );
        require(
            traderVault.getTraderBalance(msg.sender, c._collateralAssetId) >=
                c._collateralAbsInUsd,
            "OrderRouter: Not enough balance"
        );
        require(c._sizeAbsInUsd >= 0, "OrderRouter: Invalid size");
        require(
            c._collateralAbsInUsd >= 0,
            "OrderRouter: Invalid collateral size"
        );
    }

    function increaseCollateral() external {
        // call when sizeDelta = 0 (leverage down)
    }

    function decreaseCollateral() external {
        // call when sizeDelta = 0 (leverage up)
    }

    function placeLimitOrder(ITraderVault.OrderContext calldata c) external {
        _validateOrder(c);
        orderBook.placeLimitOrder(c);
    }

    function cancelLimitOrder() public {}

    function updateLimitOrder() public {}

    function placeMarketOrder(
        ITraderVault.OrderContext calldata c
    ) external returns (bytes32) {
        _validateOrder(c);

        return executeMarketOrder(c);
    }

    function executeMarketOrder(
        ITraderVault.OrderContext calldata c
    ) private returns (bytes32) {
        bool isBuy = c._isLong == c._isIncrease;

        uint256 markPrice = getMarkPrice(
            c._indexAssetId,
            c._sizeAbsInUsd,
            isBuy
        );

        bytes32 key = _getPositionKey(
            msg.sender,
            c._isLong,
            c._indexAssetId,
            c._collateralAssetId
        );

        // validations
        c._isIncrease
            ? traderVault.validateIncreaseExecution(c)
            : traderVault.validateDecreaseExecution(c, key, markPrice);

        // update state variables
        if (c._isIncrease) {
            traderVault.decreaseTraderBalance(
                msg.sender,
                c._collateralAssetId,
                c._collateralAbsInUsd
            );
            traderVault.increaseReserveAmounts(
                c._collateralAssetId,
                c._collateralAbsInUsd
            );
        }

        // fill the order
        traderVault.fillOrder(
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

        uint256 positionSizeInUsd = traderVault.getPositionSizeInUsd(key);

        if (!c._isIncrease && c._sizeAbsInUsd == positionSizeInUsd) {
            // close position
            traderVault.deletePosition(key);
        } else {
            // partial close position
            traderVault.updatePosition(
                key,
                markPrice,
                c._sizeAbsInUsd,
                c._collateralAbsInUsd,
                c._isIncrease, // isIncreaseInSize
                c._isIncrease // isIncreaseInCollateral
            );
        }

        // update global position state
        traderVault.updateGlobalPositionState(
            c._isLong,
            c._isIncrease,
            c._indexAssetId,
            c._sizeAbsInUsd,
            c._collateralAbsInUsd,
            markPrice
        );

        return key;
    }
}
