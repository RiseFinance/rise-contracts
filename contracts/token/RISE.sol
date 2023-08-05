// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RiseFinanceToken is ERC20 {
    constructor() ERC20("Rise Finance Token", "RISE") {}
}
