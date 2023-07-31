// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";
import "../position/PositionUtils.sol";

contract GlobalState is PositionUtils {
    mapping(uint256 => GlobalPositionState) private globalLongPositionStates; // marketId => GlobalPositionState
    mapping(uint256 => GlobalPositionState) private globalShortPositionStates; // marketId => GlobalPositionState

    function getOpenInterest(
        uint256 _marketId,
        bool _isLong
    ) public view returns (uint256) {}

    function getGlobalLongPositionState(
        uint256 _marketId
    ) external view returns (GlobalPositionState memory) {
        return globalLongPositionStates[_marketId];
    }

    function getGlobalShortPositionState(
        uint256 _marketId
    ) external view returns (GlobalPositionState memory) {
        return globalShortPositionStates[_marketId];
    }

    function updateGlobalLongPositionState(
        bool _isIncrease,
        uint256 _marketId,
        uint256 _sizeDeltaAbs,
        uint256 _marginDeltaAbs,
        uint256 _markPrice
    ) external {
        globalLongPositionStates[_marketId].avgPrice = _getNextAvgPrice(
            _isIncrease,
            globalLongPositionStates[_marketId].totalSize,
            globalLongPositionStates[_marketId].avgPrice,
            _sizeDeltaAbs,
            _markPrice
        );

        if (_isIncrease) {
            globalLongPositionStates[_marketId].totalSize += _sizeDeltaAbs;
            globalLongPositionStates[_marketId].totalMargin += _marginDeltaAbs;
        } else {
            globalLongPositionStates[_marketId].totalSize -= _sizeDeltaAbs;
            globalLongPositionStates[_marketId].totalMargin -= _marginDeltaAbs;
        }
    }

    function updateGlobalShortPositionState(
        bool _isIncrease,
        uint256 _marketId,
        uint256 _sizeDeltaAbs,
        uint256 _marginDeltaAbs,
        uint256 _markPrice
    ) external {
        globalShortPositionStates[_marketId].avgPrice = _getNextAvgPrice(
            _isIncrease,
            globalShortPositionStates[_marketId].totalSize,
            globalShortPositionStates[_marketId].avgPrice,
            _sizeDeltaAbs,
            _markPrice
        );

        if (_isIncrease) {
            globalShortPositionStates[_marketId].totalSize += _sizeDeltaAbs;
            globalShortPositionStates[_marketId].totalMargin += _marginDeltaAbs;
        } else {
            globalShortPositionStates[_marketId].totalSize -= _sizeDeltaAbs;
            globalShortPositionStates[_marketId].totalMargin -= _marginDeltaAbs;
        }
    }
}
