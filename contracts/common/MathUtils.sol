// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "hardhat/console.sol"; // test-only

contract MathUtils {
    function _min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function _abs(int256 x) public pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }
}
