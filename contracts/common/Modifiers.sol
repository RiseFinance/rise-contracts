// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract Modifiers {
    modifier onlyKeeper() {
        require(true, "only keeper"); // FIXME: implementation
        _;
    }
}
