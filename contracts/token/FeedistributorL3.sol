// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../fee/PositionFee.sol";
import "../token/RISE.sol";
import "./Feedistributor.sol";
import {ArbSys} from "../crosschain/interfaces/l3/ArbSys.sol";

contract FeedistributorL3 {
    PositionFee public positionFee;
    address public feedistributorL2;

    uint256 feeratio = 100;
    uint256 constant feeratioPrecision = 100;

    constructor(
        address _positionFee,
        address _feedistributorL2
    ) {
        positionFee = PositionFee(_positionFee);
        feedistributorL2 = _feedistributorL2;
    }

    function setfeeration(uint256 _feeratio) external {
        feeratio = _feeratio;
    }
    

// L3 -> L2 function call with parameter : collectedPositionFee
    function callstartdistribution(
        
    ) public {
        uint256 total = positionFee.getcollectedPositionFees();
        total = total * feeratio / feeratioPrecision;
        bytes4 selector;
        bytes memory data;
        selector = Feedistributor.startDistribution.selector;
        data = abi.encodeWithSelector(
            selector,
            total
        );
        ArbSys(address(100)).sendTxToL1(feedistributorL2, data); //what is 100?
        

        positionFee.deductfeeFromcollectedPositionFees(total);
        
    }
    
}