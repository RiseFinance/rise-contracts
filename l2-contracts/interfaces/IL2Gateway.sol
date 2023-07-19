// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IL2Gateway {
    function depositEthToL3(
        uint256,
        uint256,
        uint256,
        uint256
    ) external payable returns (uint256);

    function withdrawEthFromOutbox(address, uint256) external;
}
