// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IL2MarginGateway {
    function depositEthToL3(
        uint256,
        uint256,
        uint256,
        uint256
    ) external payable returns (uint256);

    function _withdrawEthFromOutbox(address, uint256) external;
}
