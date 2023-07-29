// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../account/TraderVault.sol";
import "../risepool/RisePool.sol";
import "./interfaces/l2/IL2Gateway.sol";
import "./interfaces/l3/IL3Gateway.sol";
import "../common/Constants.sol";
import {ArbSys} from "./interfaces/l3/ArbSys.sol";

contract L3Gateway is IL3Gateway, Constants {
    address public l2GatewayAddress;
    TraderVault public traderVault;
    RisePool public risePool;

    constructor(address _traderVault, address _l2Gateway) {
        traderVault = TraderVault(_traderVault);
        l2GatewayAddress = _l2Gateway;
    }

    // -------------------- Call L3 Contracts --------------------

    // Deposit
    function increaseTraderBalance(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) external {
        // TODO: msg.sender validation?
        traderVault.increaseTraderBalance(_trader, _assetId, _amount);
    }

    // Add Liquidity
    function addLiquidity(
        uint256 _marketId,
        bool _isLong,
        uint256 _amount
    ) external {
        risePool.addLiquidity(_marketId, _isLong, _amount);
    }

    // -------------------- L3 -> L2 Messaging --------------------

    // Withdraw
    // Should be called via retryable tickets
    // TODO: L3 gas fee should be paid by the L2 user (or by L3 admin contract)
    function withdrawEthToL2(address _trader, uint256 _amount) external {
        // TODO: msg.sender validation?
        // FIXME: restrict this function call from L3 EOA
        uint256 balance = traderVault.getTraderBalance(_trader, ETH_ID);
        require(balance >= _amount, "L3Gateway: insufficient balance");

        traderVault.decreaseTraderBalance(_trader, ETH_ID, _amount);

        bytes memory data = abi.encodeWithSelector(
            IL2Gateway._withdrawEthFromOutbox.selector,
            _trader, // _dest => not allowing to designate a different recipient address
            _amount // _amount
        );
        ArbSys(address(100)).sendTxToL1(l2GatewayAddress, data);
    }
}
