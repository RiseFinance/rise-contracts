// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../token/RMM.sol";

// Deals with listing new markets and updating existing ones
// * Listing new markets
// * Asset ID ++, market token addresses register, LP pool register, LP token generating, etc.

contract MarketFactory {
    // TODO: create LP token contract for each market

    RMM rmm = new RMM{}();
}
