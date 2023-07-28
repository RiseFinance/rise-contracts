// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IL3Gateway {
    function increaseTraderBalance(address, uint256, uint256) external;

    function addLiquidity(uint256, bool, uint256) external;

    function withdrawEthToL2(address, uint256) external;
}
