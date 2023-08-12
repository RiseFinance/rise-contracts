// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

uint256 constant USD_ID = 0; // FIXME:
uint256 constant ETH_ID = 1;

uint256 constant PRICE_BUFFER_PRECISION = 1e20;
uint256 constant USD_PRECISION = 1e20;
uint256 constant DECAY_CONSTANT = (PRICE_BUFFER_PRECISION / 100) / 300; // 1% decay per 5 miniutes
// uint256 public constant PRICE_BUFFER_DELTA_TO_SIZE =
// ((100000) * USD_PRECISION) / (PRICE_BUFFER_PRECISION / 100); // 1% price buffer per 100,000 USD

// uint256 constant PRICE_BUFFER_DELTA_TO_SIZE = 1e28 / (100000 * 100 * 1e20); // FIXME:

uint256 constant PARTIAL_RATIO_PRECISION = 1e8;
uint256 constant SIZE_TO_PRICE_BUFFER_PRECISION = 1e10;
