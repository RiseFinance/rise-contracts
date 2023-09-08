// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PositionFee.sol";
import "../token/RISE.sol";

contract Feedistributor {
    RISE public rise;
    PositionFee public positionFee;

    constructor(address _rise, address _positionFee) {
        rise = RISE(_rise);
        positionFee = PositionFee(_positionFee);
    }

    function distributeFee(
        uint256 _marketId,
        uint256 _size,
        bool _isLong,
        address _trader
    ) external {
        rise.mintRISE(_trader, _size);
    }
}