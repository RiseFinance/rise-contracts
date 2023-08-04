// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../account/TraderVault.sol";
import "../position/PositionVault.sol";
import "../common/structs.sol";

contract PositionHistory {
    TraderVault public traderVault;
    PositionVault public positionVault;

    mapping(address => mapping(uint256 => PositionRecord))
        public positionRecords; // userAddress => traderPositionRecordId => PositionRecord (closed positions by trader)

    /**
     * @dev Position Lifecycle
     * Open Position => Update Position => Close Position
     * Open Positions are recorded in PositionVault
     *
     * Update Position Scenarios
     * 1) Increase in Size
     * 2) Decrease in Size
     * 3) Increase in Margin (Deleveraging)
     * 4) Decrease in Margin (Leveraging)
     */

    function openPositionRecord(
        address _trader,
        uint256 _marketId,
        uint256 _maxSize,
        uint256 _avgOpenPrice,
        uint256 _avgClosePrice
    ) external returns (uint256) {
        // use positionCount as positionRecordId
        uint256 traderPositionRecordCount = traderVault
            .getTraderPositionRecordCount(_trader);

        positionRecords[_trader][traderPositionRecordCount] = PositionRecord(
            false, // isClosed
            0, // closingPnl
            0, // cumulativeRealizedPnl
            _marketId,
            _maxSize,
            _avgOpenPrice,
            _avgClosePrice,
            block.timestamp,
            0 // closeTimestamp
        );

        traderVault.setTraderPositionRecordCount(
            _trader,
            traderPositionRecordCount + 1
        );

        return traderPositionRecordCount;
    }

    /// @notice (Important) call this function after updating position in PositionVault (updateOpenPosition)
    function updatePositionRecord(
        address _trader,
        bytes32 _key,
        uint256 _positionRecordId,
        bool _isIncrease
    ) external {
        // FIXME: increase / decrease / leveraging / deleveraging 주문 종류에 따라서 필요한 필드 업데이트
        // TODO: Enum 활용
        PositionRecord storage positionRecord = positionRecords[_trader][
            _positionRecordId
        ];

        OpenPosition memory openPosition = positionVault.getPosition(_key);

        require(!positionRecord.isClosed, "Position already closed");

        // update maxSize
        if (openPosition.size > positionRecord.maxSize) {
            positionRecord.maxSize = openPosition.size;
        }

        // update avgOpenPrice
        if (_isIncrease) {
            positionRecord.avgOpenPrice = openPosition.avgOpenPrice;
        }
        // no need to update PnL for position records for decreasing position (only for closed positions)
    }

    function closePositionRecord(
        address _trader,
        bytes32 _key,
        uint256 _positionRecordId
    ) external {
        PositionRecord storage positionRecord = positionRecords[_trader][
            _positionRecordId
        ];

        OpenPosition memory openPosition = positionVault.getPosition(_key);

        // TODO:
        // update avgClosePrice
        // update closingPnl

        // update isClosed
        positionRecord.isClosed = true;

        // update closeTimestamp
        positionRecord.closeTimestamp = block.timestamp;
    }
}
