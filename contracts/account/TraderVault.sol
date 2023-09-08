// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../crosschain/interfaces/l3/ArbSys.sol";
import "../position/PositionVault.sol";
import "../market/Market.sol";
import "../order/OrderUtils.sol";

// TODO: check - `override` needed for function declared in the interface `IL3Vault`?
contract TraderVault is PositionVault{
    // TODO: change to traderMarginBalances?
    Market public market;
    mapping(address => mapping(uint256 => uint256)) public traderBalances; // userAddress => assetId => Balance
    mapping(address => uint256) public traderOrderRecordCounts; // userAddress => orderCount
    mapping(address => uint256) public traderPositionRecordCounts; // userAddress => positionCount
    mapping(address => bool) public isIsolated; // trader's margin mode

    constructor(address _funding, address _priceManager, address _market) PositionVault(_funding, _priceManager) {
        market = Market(_market);
    }

    OpenPosition[] userpositions;
    
    function changeMarginMode() public {
        // TODO: allowed to change the margin mode only when there is no open position for the trader
        isIsolated[msg.sender] = !isIsolated[msg.sender];
    }

    // from DA server (or from EVM storage)
    function getTraderHotOpenPosition(address user) public view returns (OpenPosition[] memory, uint256) {
        uint256 _positionCount = market.globalMarketIdCounter();
        OpenPosition[] memory _userpositions = new OpenPosition[](_positionCount * 2);
        uint256 _userpositionCount = 0;
        for (uint256 i = 0; i < _positionCount; i++) {
            if(openPositions[OrderUtils._getPositionKey(user,true, i)].size > 0) {
                _userpositions[_userpositionCount++] = openPositions[OrderUtils._getPositionKey(user,true, i)];
            }
            if(openPositions[OrderUtils._getPositionKey(user,false, i)].size > 0) {
                _userpositions[_userpositionCount++] = openPositions[OrderUtils._getPositionKey(user,false, i)];
            }
        }
        
        return (_userpositions, _userpositionCount);

    }

    function getTraderOpenPositionKeys(address user) public returns (bytes32[] memory) {}

    
    function getTraderTotalUnrealizedPnl() public {}

    function getTraderTotalMaintenanceMargin() public {}

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
    function getTraderOrderRecordCount(
        address _trader
    ) external view returns (uint256) {
        return traderOrderRecordCounts[_trader];
    }

    // onlyOrderHistory
    function setTraderOrderRecordCount(
        address _trader,
        uint256 _count
    ) external {
        traderOrderRecordCounts[_trader] = _count;
    }

    // onlyPositionHistory
    function getTraderPositionRecordCount(
        address _trader
    ) external view returns (uint256) {
        return traderPositionRecordCounts[_trader];
    }

    // onlyPositionHistory
    function setTraderPositionRecordCount(
        address _trader,
        uint256 _count
    ) external {
        traderPositionRecordCounts[_trader] = _count;
    }
}
