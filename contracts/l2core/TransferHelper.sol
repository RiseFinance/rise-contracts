// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract TransferHelper {
    // transafer functions

    function _transferEth(address payable _to, uint256 _amount) internal {
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "TransferHelper: ETH transfer failed");
    }
}
