// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";

import "../position/PositionVault.sol";
import "../position/PositionUtils.sol";
import "../account/TraderVault.sol";

contract PositionHistory is PositionUtils {
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
            0, // cumulativeRealizedPnl
            0, // cumulativeClosedSize
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
        bool _isIncrease,
        int256 _pnl,
        uint256 _sizeAbs,
        uint256 _avgExecPrice
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

        // Increasing Position: update avgOpenPrice
        // Decreasing Position: update cumulativeRealizedPnl
        if (_isIncrease) {
            positionRecord.avgOpenPrice = openPosition.avgOpenPrice;
        } else {
            // update avgClosePrice
            _updateAvgClosePrice(positionRecord, _sizeAbs, _avgExecPrice);
            _updateCumulativeRealizedPnl(positionRecord, _pnl);
        }
        // no need to update PnL for position records for decreasing positzion (only for closed positions)
    }

    function closePositionRecord(
        address _trader,
        uint256 _positionRecordId,
        int256 _pnl,
        uint256 _sizeAbs,
        uint256 _avgExecPrice
    ) external {
        PositionRecord storage positionRecord = positionRecords[_trader][
            _positionRecordId
        ];

        // update avgClosePrice
        _updateAvgClosePrice(positionRecord, _sizeAbs, _avgExecPrice);

        // update final cumulativeRealizedPnl (closingPnl)
        _updateCumulativeRealizedPnl(positionRecord, _pnl);

        // update isClosed
        positionRecord.isClosed = true;

        // update closeTimestamp
        positionRecord.closeTimestamp = block.timestamp;
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
        uint256 newAvgClosePrice = _getNextAvgPrice(
            false, // _isIncreaseInSize
            _positionRecord.cumulativeClosedSize, // _prevSize
            _positionRecord.avgClosePrice, // _prevAvgPrice
            _sizeDeltaAbs, // _sizeDeltaAbs
            _decreasingPrice // _markPrice
        );

        _positionRecord.avgClosePrice = newAvgClosePrice;
    }
}
