// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";
import "../common/params.sol";
import "../common/enums.sol";

import "../account/TraderVault.sol";

contract OrderHistory {
    TraderVault public traderVault; // TODO: check - the pattern?

    mapping(address => mapping(uint256 => OrderRecord)) public orderRecords; // userAddress => traderOrderRecordId => OrderRecord (filled orders by trader)

    // TODO: check - Filled Order는 항상 Position과 N:1로 연결될 수 있지만, Open Order, Canceled Order 등에는 연결된 Position이 없을 수 있음

    constructor(address _traderVault) {
        traderVault = TraderVault(_traderVault);
    }

    function createOrderRecord(CreateOrderRecordParams memory p) external {
        // use orderCount as orderRecordId
        uint256 traderOrderRecordCount = traderVault.getTraderOrderRecordCount(
            p._trader
        );

        orderRecords[p._trader][traderOrderRecordCount] = OrderRecord(
            p._orderType,
            p._isLong,
            p._isIncrease,
            p._positionRecordId,
            p._marketId,
            p._sizeAbs,
            p._marginAbs,
            p._executionPrice,
            block.timestamp
        );

        traderVault.setTraderOrderRecordCount(
            p._trader,
            traderOrderRecordCount + 1
        );
    }
}
