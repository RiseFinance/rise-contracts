// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Utils.sol";
import "./Structs.sol";

contract CommonContext is Utils, Structs {
    modifier onlyKeeper() {
        require(true, "only keeper"); // FIXME: implementation
        _;
    }
}
