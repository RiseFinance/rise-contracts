// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/l2/IL2MarginGateway.sol";
import "./interfaces/l2/IL2LiquidityGateway.sol";
import "./interfaces/l3/IL3Gateway.sol";

import "../common/structs.sol";

import "../account/TraderVault.sol";
import "../risepool/RisePool.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";
import {ArbSys} from "./interfaces/l3/ArbSys.sol";
import {ETH_ID} from "../common/constants.sol";

contract L3Gateway is IL3Gateway {
    address public l2MarginGatewayAddress;
    address public l2LiquidityGatewayAddress;
    TraderVault public traderVault;
    TokenInfo public tokenInfo;
    Market public market;
    RisePool public risePool;

    constructor(
        address _traderVault,
        address _tokenInfo,
        address _risePool,
        address _market,
        address _l2MarginGateway,
        address _l2LiquidityGateway
    ) {
        traderVault = TraderVault(_traderVault);
        tokenInfo = TokenInfo(_tokenInfo);
        risePool = RisePool(_risePool);
        market = Market(_market);
        l2MarginGatewayAddress = _l2MarginGateway; // L2 address
        l2LiquidityGatewayAddress = _l2LiquidityGateway; // L2 address
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

        // FIXME: token address not registered in L3 TokenInfo contract (currently)
        address tokenAddress = tokenInfo.getTokenAddressFromAssetId(_assetId);
        // FIXME: currently not working

        bytes4 selector;
        bytes memory data;
        if (_assetId == ETH_ID) {
            selector = IL2MarginGateway._withdrawEthFromOutbox.selector;
            data = abi.encodeWithSelector(
                selector,
                _trader, // _dest => not allowing to designate a different recipient address
                _amount // _amount
            );
        } else {
            selector = IL2MarginGateway._withdrawERC20FromOutbox.selector;
            data = abi.encodeWithSelector(
                selector,
                _trader, // _dest => not allowing to designate a different recipient address
                _amount, // _amount
                tokenAddress // _token
            );
        }

        ArbSys(address(100)).sendTxToL1(l2MarginGatewayAddress, data);
    }

    // Remove Liquidity
    // Should be called via retryable tickets
    function removeLiquidityToL2(
        uint256 _marketId,
        bool _isLongReserve,
        address _recipient,
        uint256 _amount
    ) external {
        // FIXME: check if the recipient can remove the `_amount` of liquidity.

        require(
            risePool.getLongPoolCapacity(_marketId) >= _amount,
            "L3Gateway: insufficient long pool capacity"
        );

        risePool.removeLiquidity(_marketId, _isLongReserve, _amount);

        MarketInfo memory marketInfo = market.getMarketInfo(_marketId);
        uint256 _assetId = _isLongReserve
            ? marketInfo.longReserveAssetId
            : marketInfo.shortReserveAssetId;

        address tokenAddress = tokenInfo.getTokenAddressFromAssetId(_assetId);

        bytes4 selector;
        bytes memory data;

        if (_assetId == ETH_ID) {
            selector = IL2LiquidityGateway
                ._removeEthLiquidityFromOutbox
                .selector;
            data = abi.encodeWithSelector(selector, _recipient, _amount);
        } else {
            selector = IL2LiquidityGateway
                ._removeERC20LiquidityFromOutbox
                .selector;
            data = abi.encodeWithSelector(
                selector,
                _recipient,
                _amount,
                tokenAddress
            );
        }

        ArbSys(address(100)).sendTxToL1(l2LiquidityGatewayAddress, data);
    }
}
