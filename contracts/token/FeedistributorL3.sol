// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../fee/PositionFee.sol";
import "../token/RISE.sol";
import "./Feedistributor.sol";
import {ArbSys} from "../crosschain/interfaces/l3/ArbSys.sol";

contract FeedistributorL3 {
    PositionFee public positionFee;

    uint256 feeratio = 100;
    uint256 constant feeratioPrecision = 100;

    constructor(address _positionFee) {
        positionFee = PositionFee(_positionFee);
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
        ArbSys(address(100)).sendTxToL1(address(this), data);

        positionFee.deductfeeFromcollectedPositionFees(total);
        
    }
    
}