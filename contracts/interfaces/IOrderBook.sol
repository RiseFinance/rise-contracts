// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IL3Vault.sol";

interface IOrderBook {
    function placeLimitOrder(IL3Vault.OrderContext calldata) external;

    function executeLimitOrdersAndGetFinalMarkPrice(
        bool,
        uint256,
        uint256,
        uint256
    ) external returns (uint256);
}
