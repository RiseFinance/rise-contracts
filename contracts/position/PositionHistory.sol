// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";
import "../common/params.sol";

import "../position/PositionVault.sol";
import "../position/PositionUtils.sol";
import "../account/TraderVault.sol";

contract PositionHistory {
    PositionVault public positionVault;
    TraderVault public traderVault;

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

    constructor(address _positionVault, address _traderVault) {
        positionVault = PositionVault(_positionVault);
        traderVault = TraderVault(_traderVault);
    }

    function openPositionRecord(
        OpenPositionRecordParams memory p
    ) external returns (uint256) {
        // use positionCount as positionRecordId
        uint256 traderPositionRecordCount = traderVault
            .getTraderPositionRecordCount(p._trader);

        positionRecords[p._trader][traderPositionRecordCount] = PositionRecord(
            false, // isClosed
            0, // cumulativeRealizedPnl
            0, // cumulativeClosedSize
            p._marketId,
            p._maxSize,
            p._avgOpenPrice,
            p._avgClosePrice,
            block.timestamp,
            0 // closeTimestamp
        );

        traderVault.setTraderPositionRecordCount(
            p._trader,
            traderPositionRecordCount + 1
        );

        return traderPositionRecordCount;
    }

    /// @notice (Important) call this function after updating position in PositionVault (updateOpenPosition)
    function updatePositionRecord(
        UpdatePositionRecordParams memory p
    ) external {
        // FIXME: increase / decrease / leveraging / deleveraging 주문 종류에 따라서 필요한 필드 업데이트
        // TODO: Enum 활용
        PositionRecord storage positionRecord = positionRecords[p._trader][
            p._positionRecordId
        ];

        OpenPosition memory openPosition = positionVault.getPosition(p._key);

        require(!positionRecord.isClosed, "Position already closed");

        // update maxSize
        if (openPosition.size > positionRecord.maxSize) {
            positionRecord.maxSize = openPosition.size;
        }

        // Increasing Position: update avgOpenPrice
        // Decreasing Position: update cumulativeRealizedPnl
        if (p._isIncrease) {
            positionRecord.avgOpenPrice = openPosition.avgOpenPrice;
        } else {
            // update cumulativeClosedSize
            _updateCumulativeClosedSize(positionRecord, p._sizeAbs);

            // update avgClosePrice
            _updateAvgClosePrice(positionRecord, p._sizeAbs, p._avgExecPrice);

            // update cumulativeRealizedPnl
            _updateCumulativeRealizedPnl(positionRecord, p._pnl);
        }
        // no need to update PnL for position records for decreasing positzion (only for closed positions)
    }

    function closePositionRecord(ClosePositionRecordParams memory p) external {
        PositionRecord storage positionRecord = positionRecords[p._trader][
            p._positionRecordId
        ];

        // update cumulativeClosedSize
        _updateCumulativeClosedSize(positionRecord, p._sizeAbs);

        // update avgClosePrice
        _updateAvgClosePrice(positionRecord, p._sizeAbs, p._avgExecPrice);

        // update final cumulativeRealizedPnl (closingPnl)
        _updateCumulativeRealizedPnl(positionRecord, p._pnl);

        // update isClosed
        positionRecord.isClosed = true;

        // update closeTimestamp
        positionRecord.closeTimestamp = block.timestamp;
    }

    function _updateCumulativeClosedSize(
        PositionRecord storage _positionRecord,
        uint256 _sizeDeltaAbs
    ) private {
        _positionRecord.cumulativeClosedSize += _sizeDeltaAbs;
    }

    function _updateCumulativeRealizedPnl(
        PositionRecord storage _positionRecord,
        int256 _pnl
    ) private {
        _positionRecord.cumulativeRealizedPnl += _pnl;
    }

    function _updateAvgClosePrice(
        PositionRecord storage _positionRecord,
        uint256 _sizeDeltaAbs,
        uint256 _decreasingPrice
    ) private {
        uint256 newAvgClosePrice = PositionUtils._getNextAvgPrice(
            false, // _isIncreaseInSize
            _positionRecord.cumulativeClosedSize, // _prevSize
            _positionRecord.avgClosePrice, // _prevAvgPrice
            _sizeDeltaAbs, // _sizeDeltaAbs
            _decreasingPrice // _markPrice
        );

        _positionRecord.avgClosePrice = newAvgClosePrice;
    }
}
