// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/structs.sol";
import "../common/params.sol";

import "../position/PositionUtils.sol";

contract GlobalState {
    mapping(uint256 => GlobalPositionState) private globalLongPositionStates; // marketId => GlobalPositionState
    mapping(uint256 => GlobalPositionState) private globalShortPositionStates; // marketId => GlobalPositionState

    // Global Long OI
    function getLongOpenInterest(
        uint256 _marketId
    ) public view returns (uint256) {
        return globalLongPositionStates[_marketId].totalSize;
    }

    // Global Short OI
    function getShortOpenInterest(
        uint256 _marketId
    ) public view returns (uint256) {
        return globalShortPositionStates[_marketId].totalSize;
    }

    // (Long OI - Short OI)
    function getLongShortOIDiff(
        uint256 _marketId
    ) public view returns (int256) {
        return
            int256(globalLongPositionStates[_marketId].totalSize) -
            int256(globalShortPositionStates[_marketId].totalSize);
    }

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
        if (p._isIncrease) {
            globalLongPositionStates[p._marketId].avgPrice = PositionUtils
                ._getNextAvgPrice(
                    globalLongPositionStates[p._marketId].totalSize,
                    globalLongPositionStates[p._marketId].avgPrice,
                    p._sizeDeltaAbs,
                    p._markPrice
                );

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
        if (p._isIncrease) {
            globalShortPositionStates[p._marketId].avgPrice = PositionUtils
                ._getNextAvgPrice(
                    globalShortPositionStates[p._marketId].totalSize,
                    globalShortPositionStates[p._marketId].avgPrice,
                    p._sizeDeltaAbs,
                    p._markPrice
                );

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
