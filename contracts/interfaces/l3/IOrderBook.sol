// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../l3core/common/Structs.sol";
import "./IL3Vault.sol";

interface IOrderBook {

    function getOrderRequest(bool, uint256, uint256, uint256) external view returns (Structs.OrderRequest memory);

    function placeLimitOrder(IL3Vault.OrderContext calldata) external;

    function executeLimitOrdersAndGetFinalMarkPrice(
        bool,
        uint256,
        uint256,
        uint256
    ) external returns (uint256);
}
