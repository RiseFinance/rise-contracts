// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../common/params.sol";

import "hardhat/console.sol"; // test-only

library MathUtils {
    using SafeCast for int256;
    using SafeCast for uint256;

    function _min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function _abs(int256 x) public pure returns (uint256) {
        return x >= 0 ? x.toUint256() : (-x).toUint256();
    }

    function _weightedAverage(
        uint256 w_a,
        uint256 w_b,
        uint256 a,
        uint256 b
    ) public pure returns (uint256) {
        if (a + b == 0) return 0;
        return (w_a * a + w_b * b) / (a + b);
    }

    function _weightedAverage(
        int256 w_a,
        int256 w_b,
        uint256 a,
        uint256 b
    ) public pure returns (int256) {
        int256 _a = a.toInt256();
        int256 _b = b.toInt256();
        if (_a + _b == 0) return 0;
        return (w_a * _a + w_b * _b) / (_a + _b);
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) public pure returns (uint256) {
        return Math.mulDiv(x, y, denominator);
    }

    function _clamp(
        int256 x,
        int256 min,
        int256 max
    ) public pure returns (int256) {
        return x < min ? min : x > max ? max : x;
    }
}
