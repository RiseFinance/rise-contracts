// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";
import "../common/params.sol";

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
        UpdateGlobalPositionStateParams memory p
    ) external {
        globalLongPositionStates[p._marketId].avgPrice = _getNextAvgPrice(
            p._isIncrease,
            globalLongPositionStates[p._marketId].totalSize,
            globalLongPositionStates[p._marketId].avgPrice,
            p._sizeDeltaAbs,
            p._markPrice
        );

        if (p._isIncrease) {
            globalLongPositionStates[p._marketId].totalSize += p._sizeDeltaAbs;
            globalLongPositionStates[p._marketId].totalMargin += p
                ._marginDeltaAbs;
        } else {
            globalLongPositionStates[p._marketId].totalSize -= p._sizeDeltaAbs;
            globalLongPositionStates[p._marketId].totalMargin -= p
                ._marginDeltaAbs;
        }
    }

    function updateGlobalShortPositionState(
        UpdateGlobalPositionStateParams memory p
    ) external {
        globalShortPositionStates[p._marketId].avgPrice = _getNextAvgPrice(
            p._isIncrease,
            globalShortPositionStates[p._marketId].totalSize,
            globalShortPositionStates[p._marketId].avgPrice,
            p._sizeDeltaAbs,
            p._markPrice
        );

        if (p._isIncrease) {
            globalShortPositionStates[p._marketId].totalSize += p._sizeDeltaAbs;
            globalShortPositionStates[p._marketId].totalMargin += p
                ._marginDeltaAbs;
        } else {
            globalShortPositionStates[p._marketId].totalSize -= p._sizeDeltaAbs;
            globalShortPositionStates[p._marketId].totalMargin -= p
                ._marginDeltaAbs;
        }
    }
}
