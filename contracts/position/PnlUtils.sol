// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../common/constants.sol";

library PnlUtils {
    using SafeCast for uint256;
    using SafeCast for int256;

    function _calculatePnL(
        uint256 _size,
        uint256 _averagePrice,
        uint256 _markPrice,
        bool _isLong
    ) public pure returns (int256) {
        int256 pnl;
        _isLong
            ? pnl =
                (_size.toInt256() *
                    (_markPrice.toInt256() - _averagePrice.toInt256())) /
                USD_PRECISION.toInt256()
            : pnl =
            (_size.toInt256() *
                (_averagePrice.toInt256() - _markPrice.toInt256())) /
            USD_PRECISION.toInt256();
        return pnl;
    }
}
