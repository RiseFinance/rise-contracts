// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "hardhat/console.sol"; // test-only

contract MathUtils {
    using SafeCast for int256;

    function _min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function _abs(int256 x) public pure returns (uint256) {
        return x >= 0 ? x.toUint256() : (-x).toUint256();
    }

    function _clamp(
        int256 x,
        int256 min,
        int256 max
    ) public pure returns (int256) {
        return x < min ? min : x > max ? max : x;
    }
}
