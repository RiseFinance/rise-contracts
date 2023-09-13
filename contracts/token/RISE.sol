// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../fee/PositionFee.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../utils/MathUtils.sol";
import "../account/TraderVault.sol";

contract RISE is ERC20 {
    using SafeCast for uint256;
    using SafeCast for int256;  

    //RISE has same precision as USDC and margin(also USDC)
    address risemanager;
    TraderVault traderVault;
    PositionFee public positionFee;
    uint256 lastDistributionTime;
    
    constructor(
        address _positionFee,
        address _traderVault
    ) ERC20("Rise Finance Token", "RISE") {
        positionFee = PositionFee(_positionFee);
        traderVault = TraderVault(_traderVault);
        risemanager = msg.sender;    
        lastDistributionTime = block.timestamp;
    }
    
    modifier onlyRiseManager() {
        require(msg.sender == risemanager, "Only RiseManager can call this function");
        _;
    }
    
    mapping(address => uint256) private stakedRISE;
    mapping(uint256 => address) private stakerlist;
    uint256 private totalStakedRISE;
    uint256 private totalstakercount;



    function mintRISE(address _to, uint256 _amount) external onlyRiseManager{
        _mint(_to, _amount);
    }   

    function burnRISE(address _from, uint256 _amount) external onlyRiseManager{
        _burn(_from, _amount);
    }

    function balanceOfStakedRISE(address _staker) external view returns (uint256) {
        return stakedRISE[_staker];
    }

    function gettotalStakedRISE() external view returns (uint256) {
        return totalStakedRISE;
    } 



    function stakeRISE(uint256 _amount) external {
        _burn(msg.sender, _amount);
        if(stakedRISE[msg.sender] == 0){
            stakerlist[totalstakercount] = msg.sender;
            totalstakercount += 1;
        }
        stakedRISE[msg.sender] += _amount;
        
        totalStakedRISE += _amount;
        
    }
    //stake directly from user's wallet


    function stakeRISE(address _from, uint256 _amount) external onlyRiseManager{
        _burn(_from, _amount);
        if(stakedRISE[_from] == 0){
            stakerlist[totalstakercount] = _from;
            totalstakercount += 1;
        }
        stakedRISE[_from] += _amount;
        totalStakedRISE += _amount;
    }
    //distribution

    function retrieveRISE(uint256 _amount) external{
        require(stakedRISE[msg.sender] >= _amount, "Not enough RISE to retrieve");
        require(block.timestamp - lastDistributionTime > 600000, "Distribution is about to happen");
        _mint(msg.sender, _amount);

    }

    function retrieveRISE(address _to, uint256 _amount) external onlyRiseManager{
        require(stakedRISE[_to] >= _amount, "Not enough RISE to retrieve");
        require(block.timestamp - lastDistributionTime > 600000, "Distribution is about to happen");
        _mint(_to, _amount);

    }


    function startDistribution() external onlyRiseManager {
        //uint256 startTime = block.timestamp;
        //uint256 duration = 31536000; //1year   604800; //1week

        require ( block.timestamp - lastDistributionTime > 604800, "Distribution is not available yet");
        uint256 total = positionFee.getcollectedPositionFees();
        require (total > 0, "No fee to distribute");
        positionFee.deductfeeFromcollectedPositionFees(total);
        for (uint256 i = 0; i < totalstakercount; i++) {
            uint256 amount = stakedRISE[stakerlist[i]];
            
            uint256 a = MathUtils.mulDiv(amount, total, totalStakedRISE);
            traderVault.increaseTraderBalance(stakerlist[i], 0, a);
            //make position record? some track
            stakedRISE[stakerlist[i]] = 0;
            stakerlist[i] = address(0);
            
            
        }
        totalStakedRISE = 0;
        totalstakercount = 0;
        lastDistributionTime = block.timestamp;
    }


}



