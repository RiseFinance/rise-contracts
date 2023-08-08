// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../oracle/PriceManager.sol";

contract PriceUtils {
    PriceManager public priceManager;

    function _getAvgExecPrice(
        uint256 _marketId,
        uint256 _size,
        bool _isLong
    ) internal returns (uint256) {
        /**
         * // TODO: impl
         * @dev Jae Yoon
         */
        return priceManager.getAvgExecPrice(_marketId, _size, _isLong);
    }

    function _getMarkPrice(uint256 _marketId) internal returns (uint256) {
        return priceManager.getMarkPrice(_marketId);
    }

    function _getIndexPrice(uint256 _marketId) internal returns (uint256) {
        return priceManager.getIndexPrice(_marketId);
    }
}
