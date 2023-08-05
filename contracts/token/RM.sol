// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RiseMarketMaker is ERC20 {
    constructor() ERC20("Rise Market Maker Token", "RM") {}

    // TODO: onlyAdmin (or only via L2LiquidityGateway)
    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    // TODO: onlyAdmin (or only via L2LiquidityGateway)
    function burn(address _from, uint256 _amount) external {
        _burn(_from, _amount);
    }
}
