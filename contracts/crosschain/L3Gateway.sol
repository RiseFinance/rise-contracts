// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../account/TraderVault.sol";
import "../risepool/RisePool.sol";
import "./interfaces/l2/IL2MarginGateway.sol";
import "./interfaces/l2/IL2LiquidityGateway.sol";
import "./interfaces/l3/IL3Gateway.sol";
import {ArbSys} from "./interfaces/l3/ArbSys.sol";
import {ETH_ID} from "../common/constants.sol";

contract L3Gateway is IL3Gateway {
    address public l2MarginGatewayAddress;
    address public l2LiquidityGatewayAddress;
    TraderVault public traderVault;
    RisePool public risePool;

    constructor(
        address _traderVault,
        address _l2MarginGateway,
        address _l2LiquidityGateway
    ) {
        traderVault = TraderVault(_traderVault);
        l2MarginGatewayAddress = _l2MarginGateway;
        l2LiquidityGatewayAddress = _l2LiquidityGateway;
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
        bool _isLongReserve,
        uint256 _amount
    ) external {
        risePool.addLiquidity(_marketId, _isLongReserve, _amount);
    }

    // -------------------- L3 -> L2 Messaging --------------------

    // Withdraw
    // Should be called via retryable tickets
    // TODO: L3 gas fee should be paid by the L2 user (or by L3 admin contract)
    function withdrawAssetToL2(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) external {
        // TODO: msg.sender validation?
        // FIXME: restrict this function call from L3 EOA
        uint256 balance = traderVault.getTraderBalance(_trader, _assetId);
        require(balance >= _amount, "L3Gateway: insufficient balance");

        traderVault.decreaseTraderBalance(_trader, _assetId, _amount);

        if (_assetId == ETH_ID) {} else {}

        bytes4 selector = IL2MarginGateway._withdrawEthFromOutbox.selector;
        bytes memory data = abi.encodeWithSelector(
            selector,
            _trader, // _dest => not allowing to designate a different recipient address
            _amount // _amount
        );
        ArbSys(address(100)).sendTxToL1(l2MarginGatewayAddress, data);
    }
}
