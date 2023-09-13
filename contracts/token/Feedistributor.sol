// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../fee/PositionFee.sol";
import "../token/RISE.sol";
import "../token/RM.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../utils/MathUtils.sol";
import "../common/params.sol";
import "../crosschain/interfaces/l2/IInbox.sol";


contract Feedistributor {
    RISE public rise;
    
    address public risemanager;
    address public traderVault;
    uint256 lastDistributionTime;
    IInbox public inbox;

    using MathUtils for uint256;

    constructor(address _rise) {
        rise = RISE(_rise);
        
        risemanager = msg.sender;
        lastDistributionTime = block.timestamp;
    }

    modifier onlyRiseManager() {
        require(msg.sender == risemanager, "Only RiseManager can call this function");
        _;
    }

    function setrisemanager(address _risemanager) external onlyRiseManager {
        risemanager = _risemanager;
    }

    function settraderVault(address _traderVault) external onlyRiseManager {
        require(
            traderVault == address(0),
            "traderVault: already set"
        );
        traderVault = _traderVault;
    }
/*
    function distributeFee(
        uint256 _marketId,
        uint256 _size,
        bool _isLong,
        address _trader
    ) external {
        rise.mintRISE(_trader, _size);
    }
    */
   function startDistribution(
    uint256 _collectedPositionFee,
    L2ToL3FeeParams memory p
   ) public payable onlyRiseManager returns (uint256) {
        require ( block.timestamp - lastDistributionTime > 604800, "Distribution is not available yet");
        require(
            msg.value >= p._maxSubmissionCost + p._gasLimit * p._gasPriceBid,
            "L2Gateway: insufficient msg.value"
        );

        //uint256 startTime = block.timestamp;
        //uint256 duration = 31536000; //1year   604800; //1week
        uint256 totalStakedRISE = rise.gettotalStakedRISE();
        uint256 totalstakercount = rise.gettotalstakercount();

        address[] memory stakerlist = new address[](totalstakercount);
        uint256[] memory assetIds = new uint256[](totalstakercount);
        uint256[] memory amounts = new uint256[](totalstakercount);
        
        uint256 total = _collectedPositionFee;
        require (total > 0, "No fee to distribute");
        
        
        for (uint256 i = 0; i < totalstakercount; i++) {
            address j = rise.getstakerlist(i);
            uint256 amount = rise.getstakedRISE(j);
            uint256 a = amount.mulDiv(total, totalStakedRISE);
            stakerlist[i] = j;
            assetIds[i] = 0;
            amounts[i] = a;
            
            
            
        }

        //call increasetraderbalancebybatch
        bytes memory data = abi.encodeWithSelector(
            TraderVault.increaseTraderBalancebyBatch.selector,
            stakerlist,
            assetIds,
            amounts
        );
         uint256 ticketId = inbox.createRetryableTicket{
            value: p._maxSubmissionCost + p._gasLimit * p._gasPriceBid
        }(
            traderVault,
            0, // l3CallValue
            p._maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // TODO: aggregate excess fees on a L3 admin contract (not msg.sender)
            msg.sender, // callValueRefundAddress
            p._gasLimit,
            p._gasPriceBid,
            data
        );
        //reset stakedRISE, totalStakedRISE, totalstakercount, stakerlist 

        rise.afterDistribution();



        lastDistributionTime = block.timestamp;
        return ticketId;
    }
}