// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../common/structs.sol";
import "../common/params.sol";
import "../fee/Funding.sol";

import "./PositionUtils.sol";

contract PositionVault {
    using SafeCast for uint256;

    Funding public funding;

    // TODO: open <> close 사이의 position을 하나로 연결하여 기록
    mapping(bytes32 => OpenPosition) public openPositions; // positionHash => Position

    mapping(uint256 => uint256) public maxLongCapacity; // marketId => tokenCount
    mapping(uint256 => uint256) public maxShortCapacity; // marketId => tokenCount // TODO: check - is it for stablecoins?

    constructor(address _funding) {
        funding = Funding(_funding);
    }

    function getPosition(
        bytes32 _key
    ) external view returns (OpenPosition memory) {
        return openPositions[_key];
    }

    function getPositionSize(bytes32 _key) external view returns (uint256) {
        return openPositions[_key].size;
    }

    // function updateOpenPositionWithPnl(
    //     int256 _interimPnlUsd,
    //     UpdatePositionParams memory p
    // ) external {
    //     // update cumulative PnL for the open position while decreasing position

    //     // TODO: refactor
    //     OpenPosition storage _position = openPositions[p._key];
    //     _position.unrealizedPnl += _interimPnlUsd;

    //     require(
    //         p._execType == OrderExecType.DecreasePosition,
    //         "Invalid exec type"
    //     );

    //     // 기존에 PnL > 0이었을 경우, _traderHasProfitForInterimPnl가 true라면 PnL을 더해주고, false라면 빼준다.

    //     updateOpenPosition(p);
    // }

    function updateOpenPosition(UpdatePositionParams memory p) public {
        OpenPosition storage _position = openPositions[p._key];

        // trader, isLong, marketId
        if (p._isOpening) {
            _position.trader = p._trader;
            _position.isLong = p._isLong;
            _position.currentPositionRecordId = p._currentPositionRecordId;
            _position.marketId = p._marketId;
            _position.avgEntryFundingIndex = funding.getFundingIndex(
                p._marketId
            );
        }

        if (p._sizeDeltaAbs > 0 && p._isIncreaseInSize) {
            _position.avgOpenPrice = PositionUtils._getNextAvgPrice(
                p._isIncreaseInSize,
                _position.size,
                _position.avgOpenPrice,
                p._sizeDeltaAbs,
                p._executionPrice
            );
            _position.avgEntryFundingIndex = PositionUtils
                ._getNextAvgEntryFundingIndex(
                    p._isIncreaseInSize,
                    _position.size,
                    _position.avgEntryFundingIndex,
                    p._sizeDeltaAbs,
                    funding.getFundingIndex(p._marketId)
                );
        }
        _position.size = p._isIncreaseInSize
            ? _position.size + p._sizeDeltaAbs
            : _position.size - p._sizeDeltaAbs;

        _position.margin = p._isIncreaseInMargin
            ? _position.margin + p._marginDeltaAbs
            : _position.margin - p._marginDeltaAbs;

        _position.lastUpdatedTime = block.timestamp;
    }

    function deleteOpenPosition(bytes32 _key) external {
        delete openPositions[_key];
    }

    // TODO: onlyOperator
    function setMaxLongCapacity(
        uint256 _marketId,
        uint256 _tokenCount
    ) external {
        maxLongCapacity[_marketId] = _tokenCount;
    }

    // TODO: onlyOperator
    function setMaxShortCapacity(
        uint256 _marketId,
        uint256 _tokenCount
    ) external {
        maxShortCapacity[_marketId] = _tokenCount;
    }
}
