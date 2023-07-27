// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "..//common/Context.sol";
import "../interfaces/l3/ITraderVault.sol";

contract OrderHistory is Context {
    ITraderVault public traderVault; // TODO: check - the pattern?

    mapping(address => mapping(uint256 => FilledOrder)) public filledOrders; // userAddress => traderOrderCount => Order (filled orders by trader)

    constructor(address _traderVault) {
        traderVault = ITraderVault(_traderVault);
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
        uint256 traderFilledOrderCount = traderVault.getTraderFilledOrderCount(
            _trader
        );

        filledOrders[_trader][traderFilledOrderCount] = FilledOrder(
            _isMarketOrder,
            _isLong,
            _isIncrease,
            _indexAssetId,
            _collateralAssetId,
            _sizeAbsInUsd,
            _collateralAbsInUsd,
            _executionPrice
        );
        traderVault.setTraderFilledOrderCount(
            _trader,
            traderFilledOrderCount + 1
        );
    }
}
