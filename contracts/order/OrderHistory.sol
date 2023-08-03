// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../account/TraderVault.sol";
import "../common/structs.sol";

contract OrderHistory {
    TraderVault public traderVault; // TODO: check - the pattern?

    mapping(address => mapping(uint256 => OrderRecord)) public orderRecords; // userAddress => traderOrderRecordId => OrderRecord (filled orders by trader)

    // TODO: check - Filled Order는 항상 Position과 N:1로 연결될 수 있지만, Open Order, Canceled Order 등에는 연결된 Position이 없을 수 있음

    constructor(address _traderVault) {
        traderVault = TraderVault(_traderVault);
    }

    function createOrderRecord(
        address _trader,
        bool _isMarketOrder,
        bool _isLong,
        bool _isIncrease,
        uint256 _positionRecordId,
        uint256 _marketId,
        uint256 _sizeAbs,
        uint256 _marginAbs,
        uint256 _executionPrice
    ) external {
        // use orderCount as orderRecordId
        uint256 traderOrderRecordCount = traderVault.getTraderOrderRecordCount(
            _trader
        );

        orderRecords[_trader][traderOrderRecordCount] = OrderRecord(
            _isMarketOrder,
            _isLong,
            _isIncrease,
            _positionRecordId,
            _marketId,
            _sizeAbs,
            _marginAbs,
            _executionPrice,
            block.timestamp
        );

        traderVault.setTraderOrderRecordCount(
            _trader,
            traderOrderRecordCount + 1
        );
    }
}
