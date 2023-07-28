// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "hardhat/console.sol"; // test-only
import "../crosschain/interfaces/l3/ArbSys.sol";
import "../common/Context.sol";
import "../position/PositionVault.sol";
import "../risepool/RisePool.sol";

// TODO: check - `override` needed for function declared in the interface `IL3Vault`?
contract TraderVault is Context {
    RisePool public risePool;
    PositionVault public positionVault;

    mapping(address => mapping(uint256 => uint256)) public traderBalances; // userAddress => assetId => Balance
    mapping(address => uint256) public traderFilledOrderCounts; // userAddress => orderCount

    // TODO: onlyManager
    function increaseTraderBalance(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) external {
        traderBalances[_trader][_assetId] += _amount;
    }

    // TODO: onlyManager
    function decreaseTraderBalance(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) external {
        traderBalances[_trader][_assetId] -= _amount;
    }

    function getTraderBalance(
        address _trader,
        uint256 _assetId
    ) external view returns (uint256) {
        return traderBalances[_trader][_assetId];
    }

    // onlyOrderHistory
    function getTraderFilledOrderCount(
        address _trader
    ) external view returns (uint256) {
        return traderFilledOrderCounts[_trader];
    }

    // onlyOrderHistory
    function setTraderFilledOrderCount(
        address _trader,
        uint256 _count
    ) external {
        traderFilledOrderCounts[_trader] = _count;
    }
}
