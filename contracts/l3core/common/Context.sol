// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./Utils.sol";
import "./Structs.sol";

abstract contract Context is Utils, Structs {
    modifier onlyKeeper() {
        require(true, "only keeper"); // FIXME: implementation
        _;
    }
}
