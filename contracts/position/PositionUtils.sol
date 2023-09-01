// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../utils/MathUtils.sol";

library PositionUtils {
    /**
     * (new avg price) * (new size) = (old avg price) * (old size) + (mark price) * (size delta)
     * */
    function _getNextAvgPrice(
        uint256 _prevSize,
        uint256 _prevAvgPrice,
        uint256 _sizeDeltaAbs,
        uint256 _markPrice
    ) public pure returns (uint256) {
        return
            MathUtils._weightedAverage(
                _prevAvgPrice,
                _markPrice,
                _prevSize,
                _sizeDeltaAbs
            );
    }

    function _getNextAvgEntryFundingIndex(
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
                _sizeDeltaAbs
            );
    }
    
}
