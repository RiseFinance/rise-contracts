// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/Context.sol";
import "../interfaces/l3/IPriceManager.sol";
import "../interfaces/l3/IL3Vault.sol"; // TODO: change to Interface
import "../interfaces/l3/IOrderBook.sol";

// TODO: check - OrderRouter to inherit L3Vault?
contract OrderRouter is Context {
    IL3Vault l3Vault;
    IOrderBook orderBook;
    IPriceManager priceManager;

    constructor(address _l3Vault, address _orderBook, address _priceManager) {
        l3Vault = IL3Vault(_l3Vault);
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

    function _validateOrder(IL3Vault.OrderContext calldata c) internal view {
        require(
            msg.sender != address(0),
            "OrderRouter: Invalid sender address"
        );
        require(
            msg.sender == tx.origin,
            "OrderRouter: Invalid sender address (contract)"
        );
        require(
            l3Vault.isAssetIdValid(c._indexAssetId),
            "OrderRouter: Invalid index asset id"
        );
        require(
            l3Vault.getTraderBalance(msg.sender, c._collateralAssetId) >=
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

    function placeLimitOrder(IL3Vault.OrderContext calldata c) external {
        _validateOrder(c);
        orderBook.placeLimitOrder(c);
    }

    function cancelLimitOrder() public {}

    function updateLimitOrder() public {}

    function placeMarketOrder(
        IL3Vault.OrderContext calldata c
    ) external returns (bytes32) {
        _validateOrder(c);

        return executeMarketOrder(c);
    }

    function executeMarketOrder(
        IL3Vault.OrderContext calldata c
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
            ? l3Vault.validateIncreaseExecution(c)
            : l3Vault.validateDecreaseExecution(c, key, markPrice);

        // update state variables
        if (c._isIncrease) {
            l3Vault.decreaseTraderBalance(
                msg.sender,
                c._collateralAssetId,
                c._collateralAbsInUsd
            );
            l3Vault.increaseReserveAmounts(
                c._collateralAssetId,
                c._collateralAbsInUsd
            );
        }

        // fill the order
        l3Vault.fillOrder(
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

        uint256 positionSizeInUsd = l3Vault.getPositionSizeInUsd(key);

        if (!c._isIncrease && c._sizeAbsInUsd == positionSizeInUsd) {
            // close position
            l3Vault.deletePosition(key);
        } else {
            // partial close position
            l3Vault.updatePosition(
                key,
                markPrice,
                c._sizeAbsInUsd,
                c._collateralAbsInUsd,
                c._isIncrease, // isIncreaseInSize
                c._isIncrease // isIncreaseInCollateral
            );
        }

        // update global position state
        l3Vault.updateGlobalPositionState(
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
