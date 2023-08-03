// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../account/TraderVault.sol";
import "../common/structs.sol";

contract PositionHistory {
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

    function createPositionRecord(
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
            false, // hasProfit
            false, // isClosed
            _marketId,
            _maxSize,
            _avgOpenPrice,
            _avgClosePrice,
            0, // closingPnL
            block.timestamp,
            0 // closeTimestamp
        );

        traderVault.setTraderPositionRecordCount(
            _trader,
            traderPositionRecordCount + 1
        );

        return traderPositionRecordCount;
    }

    function updatePositionRecord(
        address _trader,
        uint256 _positionRecordId,
        bool _isClose,
        bool _hasProfit,
        uint256 _closingPnL
    ) external {
        // FIXME: increase / decrease / leveraging / deleveraging 주문 종류에 따라서 필요한 필드 업데이트
        // TODO: Enum 활용
        PositionRecord storage _positionRecord = positionRecords[_trader][
            _positionRecordId
        ];

        if (_isClose) {
            require(!_positionRecord.isClosed, "Position already closed");
            _positionRecord.hasProfit = _hasProfit;
            _positionRecord.closingPnL = _closingPnL;
            _positionRecord.closeTimestamp = block.timestamp;
            _positionRecord.isClosed = true;
        } else {
            require(_positionRecord.isClosed, "Position not closed yet");
        }
    }
}
