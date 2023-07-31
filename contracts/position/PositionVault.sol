// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/Structs.sol";
import "./PositionUtils.sol";

contract PositionVault is PositionUtils {
    // TODO: open <> close 사이의 position을 하나로 연결하여 기록
    mapping(bytes32 => Position) public positions; // positionHash => Position

    mapping(uint256 => uint256) public maxLongCapacity; // marketId => tokenCount
    mapping(uint256 => uint256) public maxShortCapacity; // marketId => tokenCount // TODO: check - is it for stablecoins?

    function getPosition(bytes32 _key) external view returns (Position memory) {
        return positions[_key];
    }

    function getPositionSize(bytes32 _key) external view returns (uint256) {
        return positions[_key].size;
    }

    function updatePosition(
        bytes32 _key,
        bool _isOpen,
        address _trader,
        bool _isLong,
        uint256 _marketId,
        uint256 _executionPrice,
        uint256 _sizeDeltaAbs,
        uint256 _marginDeltaAbs,
        bool _isIncreaseInSize,
        bool _isIncreaseInMargin
    ) external {
        Position storage _position = positions[_key];

        // trader, isLong, marketId
        if (_isOpen) {
            _position.trader = _trader;
            _position.isLong = _isLong;
            _position.marketId = _marketId;
        }

        if (_sizeDeltaAbs > 0 && _isIncreaseInSize) {
            _position.avgOpenPrice = _getNextAvgPrice(
                _isIncreaseInSize,
                _position.size,
                _position.avgOpenPrice,
                _sizeDeltaAbs,
                _executionPrice
            );
        }
        _position.size = _isIncreaseInSize
            ? _position.size + _sizeDeltaAbs
            : _position.size - _sizeDeltaAbs;

        _position.margin = _isIncreaseInMargin
            ? _position.margin + _marginDeltaAbs
            : _position.margin - _marginDeltaAbs;

        _position.lastUpdatedTime = block.timestamp;
    }

    function deletePosition(bytes32 _key) external {
        delete positions[_key];
    }
}
