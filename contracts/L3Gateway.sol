// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IL3Vault.sol";

contract L3Gateway {
    IL3Vault public l3Vault;

    constructor(address _l3Vault) {
        l3Vault = IL3Vault(_l3Vault);
    }

    function increaseTraderBalance(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) external {
        l3Vault.increaseTraderBalance(_trader, _assetId, _amount);
    }

    function addLiquidity(uint256 _assetId, uint256 _amount) external {
        l3Vault.addLiquidity(_assetId, _amount);
    }
}
