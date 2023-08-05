// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TransferHelper {
    using SafeERC20 for IERC20;

    // TODO: check unused functions
    // ETH transafer functions

    function _transferEth(address payable _to, uint256 _amount) internal {
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "TransferHelper: ETH transfer failed");
    }

    // ERC-20 transfer functions
    function _transferInERC20(
        address _account,
        address _token,
        uint256 _amount
    ) internal {
        IERC20(_token).safeTransferFrom(_account, address(this), _amount);
    }

    function _transferOutERC20(
        address _token,
        uint256 _amount,
        address _receiver
    ) internal {
        IERC20(_token).safeTransfer(_receiver, _amount);
    }
}
