// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../oracle/PriceManager.sol";

contract PriceUtils {
    PriceManager priceManager;

    function _getAvgExecPriceAndUpdatePriceBuffer(
        uint256 _assetId,
        uint256 _size,
        bool _isLong
    ) internal returns (uint256) {
        /**
         * // TODO: impl
         * @dev Jae Yoon
         */
        return
            priceManager.getAvgExecPriceAndUpdatePriceBuffer(
                _assetId,
                _size,
                _isLong
            );
    }
}
