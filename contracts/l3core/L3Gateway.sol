// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/Context.sol";
import "../interfaces/l3/IL3Vault.sol";
import "../interfaces/l2/IL2Gateway.sol";
import {ArbSys} from "../interfaces/l3/ArbSys.sol";

contract L3Gateway is Context {
    address public l2GateawayAddress;
    IL3Vault public l3Vault;

    constructor(address _l3Vault, address _l2Gateway) {
        l3Vault = IL3Vault(_l3Vault);
        l2GateawayAddress = _l2Gateway;
    }

    function increaseTraderBalance(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) external {
        // TODO: msg.sender validation?
        l3Vault.increaseTraderBalance(_trader, _assetId, _amount);
    }

    // function decreaseTraderBalance(
    //     address _trader,
    //     uint256 _assetId,
    //     uint256 _amount
    // ) external {
    //     l3Vault.decreaseTraderBalance(_trader, _assetId, _amount);
    // }

    function addLiquidity(uint256 _assetId, uint256 _amount) external {
        l3Vault.addLiquidity(_assetId, _amount);
    }

    // -------------------- L3 -> L2 Messaging --------------------

    // TODO: L3 gas fee should be paid by the L2 user (or by L3 admin contract)
    // Should be called via retryable tickets
    function withdrawEthToL2(address _trader, uint256 _amount) external {
        // TODO: msg.sender validation?
        uint256 balance = l3Vault.getTraderBalance(_trader, ETH_ID);
        require(balance >= _amount, "L3Gateway: insufficient balance");

        l3Vault.decreaseTraderBalance(_trader, ETH_ID, _amount);

        bytes memory data = abi.encodeWithSelector(
            IL2Gateway._withdrawEthFromOutbox.selector,
            _trader, // _dest => not allowing to designate a different recipient address
            _amount // _amount
        );
        ArbSys(address(100)).sendTxToL1(l2GateawayAddress, data);
    }
}
