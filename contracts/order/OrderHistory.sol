// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../account/TraderVault.sol";

contract OrderHistory {
    TraderVault public traderVault; // TODO: check - the pattern?

    mapping(address => mapping(uint256 => FilledOrder)) public filledOrders; // userAddress => traderOrderCount => Order (filled orders by trader)

    constructor(address _traderVault) {
        traderVault = TraderVault(_traderVault);
    }

    function fillOrder(
        address _trader,
        bool _isMarketOrder,
        bool _isLong,
        bool _isIncrease,
        uint256 _marketId,
        uint256 _sizeAbs,
        uint256 _marginAbs,
        uint256 _executionPrice
    ) external {
        uint256 traderFilledOrderCount = traderVault.getTraderFilledOrderCount(
            _trader
        );

        filledOrders[_trader][traderFilledOrderCount] = FilledOrder(
            _isMarketOrder,
            _isLong,
            _isIncrease,
            _marketId,
            _sizeAbs,
            _marginAbs,
            _executionPrice
        );
        traderVault.setTraderFilledOrderCount(
            _trader,
            traderFilledOrderCount + 1
        );
    }
}
