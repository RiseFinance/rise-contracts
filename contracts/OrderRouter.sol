// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./L3Vault.sol"; // TODO: change to Interface

contract OrderRouter is Structs {
    L3Vault l3Vault;

    constructor(address _l3Vault) {
        l3Vault = L3Vault(_l3Vault);
    }

    function placeMarketOrder(
        OrderContext calldata c
    ) external returns (bytes32) {
        // get markprice
        bool isBuy = c._isLong == c._isIncrease;

        if (c._isIncrease) {
            return l3Vault.increasePosition(c, isBuy);
        } else {
            return l3Vault.decreasePosition(c, isBuy);
        }
    }
}
