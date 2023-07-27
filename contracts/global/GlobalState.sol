// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/Context.sol";

contract GlobalState is Context {
    mapping(bool => mapping(uint256 => GlobalPositionState))
        public globalPositionStates; // assetId => GlobalPositionState

    function getGlobalPositionState(
        bool _isLong,
        uint256 _indexAssetId
    ) external view returns (GlobalPositionState memory) {
        return globalPositionStates[_isLong][_indexAssetId];
    }

    // TODO: check - for short positions, should we use marginAsset for tracking position size?
    function updateGlobalPositionState(
        bool _isLong,
        bool _isIncrease,
        uint256 _indexAssetId,
        uint256 _sizeDelta,
        uint256 _marginDelta,
        uint256 _markPrice
    ) external {
        globalPositionStates[_isLong][_indexAssetId]
            .avgPrice = _getNextAvgPrice(
            _isIncrease,
            globalPositionStates[_isLong][_indexAssetId].totalSizeInUsd,
            globalPositionStates[_isLong][_indexAssetId].avgPrice,
            _sizeDelta,
            _markPrice
        );

        if (_isIncrease) {
            globalPositionStates[_isLong][_indexAssetId]
                .totalSizeInUsd += _sizeDelta;
            globalPositionStates[_isLong][_indexAssetId]
                .totalMarginInUsd += _marginDelta;
        } else {
            globalPositionStates[_isLong][_indexAssetId]
                .totalSizeInUsd -= _sizeDelta;
            globalPositionStates[_isLong][_indexAssetId]
                .totalMarginInUsd -= _marginDelta;
        }
    }
}
