// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./TransferHelper.sol";

contract L2Vault is TransferHelper {
    using SafeERC20 for IERC20;

    error NotL2Gateway(address sender); // TODO: move to errors

    struct InOutInfo {
        uint256 index;
        bool allowed;
    }

    mapping(address => InOutInfo) public allowedL2GatewaysMap; // TODO: add setter

    function setAllowedGateway(address _allowedL2Gateway) external {
        // only owner
        require(
            allowedL2GatewaysMap[_allowedL2Gateway].index == 0,
            "L2Gateway: already allowed"
        );
        allowedL2GatewaysMap[_allowedL2Gateway].allowed = true;
    }

    // send Deposit & Liquidity tokens here from L2 gateways.
    // Holds all the funds deposited by users and liquidity providers.

    // onlyL2Gatewauy
    function _transferOutEthFromL2Vault(
        address payable _to,
        uint256 _amount
    ) external {
        if (!allowedL2GatewaysMap[msg.sender].allowed)
            revert NotL2Gateway(msg.sender);
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "TransferHelper: ETH transfer failed");
    }

    function _transferInERC20ToL2Vault(
        address _account,
        address _token,
        uint256 _amount
    ) external {
        IERC20(_token).safeTransferFrom(_account, address(this), _amount);
    }

    // onlyL2Gateway
    function _transferOutERC20FromL2Vault(
        address _token,
        uint256 _amount,
        address _receiver
    ) external {
        if (!allowedL2GatewaysMap[msg.sender].allowed)
            revert NotL2Gateway(msg.sender);
        // IERC20(_token).safeTransfer(_receiver, _amount); // error: Address:call to non-contract
        IERC20(_token).transfer(_receiver, _amount);
    }
}
