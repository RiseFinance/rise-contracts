// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/Context.sol";

contract PositionVault is Context {
    // TODO: open <> close 사이의 position을 하나로 연결하여 기록
    mapping(bytes32 => Position) public positions; // positionHash => Position

    mapping(uint256 => uint256) public maxLongCapacity; // assetId => tokenCount
    mapping(uint256 => uint256) public maxShortCapacity; // assetId => tokenCount // TODO: check - is it for stablecoins?

    function getPosition(bytes32 _key) external view returns (Position memory) {
        return positions[_key];
    }

    function getPositionSizeInUsd(
        bytes32 _key
    ) external view returns (uint256) {
        return positions[_key].sizeInUsd;
    }

    function updatePosition(
        bytes32 _key,
        uint256 _markPrice,
        uint256 _sizeDeltaAbsInUsd,
        uint256 _collateralDeltaAbsInUsd,
        bool _isIncreaseInSize,
        bool _isIncreaseInCollateral
    ) external {
        Position storage _position = positions[_key];
        if (_sizeDeltaAbsInUsd > 0 && _isIncreaseInSize) {
            _position.avgOpenPrice = _getNextAvgPrice(
                _isIncreaseInSize,
                _position.sizeInUsd,
                _position.avgOpenPrice,
                _sizeDeltaAbsInUsd,
                _markPrice
            );
        }
        _position.sizeInUsd = _isIncreaseInSize
            ? _position.sizeInUsd + _sizeDeltaAbsInUsd
            : _position.sizeInUsd - _sizeDeltaAbsInUsd;

        _position.collateralInUsd = _isIncreaseInCollateral
            ? _position.collateralInUsd + _collateralDeltaAbsInUsd
            : _position.collateralInUsd - _collateralDeltaAbsInUsd;

        _position.lastUpdatedTime = block.timestamp;
    }

    function deletePosition(bytes32 _key) external {
        delete positions[_key];
    }
}
