// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/params.sol";
import "../utils/MathUtils.sol";

contract PositionUtils {
    /**
     * (new avg price) * (new size) = (old avg price) * (old size) + (mark price) * (size delta)
     * */
    function _getNextAvgPrice(
        bool _isIncreaseInSize,
        uint256 _prevSize,
        uint256 _prevAvgPrice,
        uint256 _sizeDeltaAbs,
        uint256 _markPrice
    ) public pure returns (uint256) {
        // if (_isIncreaseInSize) {
        //     uint256 newSize = _prevSize + _sizeDeltaAbs;
        //     uint256 nextAvgPrice = newSize == 0
        //         ? 0
        //         : (_prevAvgPrice * _prevSize + _markPrice * _sizeDeltaAbs) /
        //             newSize;
        //     return nextAvgPrice;
        // } else {
        //     uint256 newSize = _prevSize - _sizeDeltaAbs;
        //     uint256 nextAvgPrice = newSize == 0
        //         ? 0
        //         : (_prevAvgPrice * _prevSize - _markPrice * _sizeDeltaAbs) /
        //             newSize;
        //     return nextAvgPrice;
        // }
        return
            MathUtils._weightedAverage(
                _prevAvgPrice,
                _markPrice,
                _prevSize,
                _sizeDeltaAbs,
                _isIncreaseInSize
            );
    }

    function _getNextAvgEntryFundingIndex(
        bool _isIncreaseInSize,
        uint256 _prevSize,
        int256 _prevAvgEntryFundingIndex,
        uint256 _sizeDeltaAbs,
        int256 _currentFundingIndex
    ) public pure returns (int256) {
        return
            MathUtils._weightedAverage(
                _prevAvgEntryFundingIndex,
                _currentFundingIndex,
                _prevSize,
                _sizeDeltaAbs,
                _isIncreaseInSize
            );
    }
}
