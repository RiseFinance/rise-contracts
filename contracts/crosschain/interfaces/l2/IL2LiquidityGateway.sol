// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IL2LiquidityGateway {
    function addEthLiquidityToL3(
        uint256 _marketId,
        bool _isLong, // LongReserveToken or ShortReserveToken
        uint256 _addAmount,
        uint256 _maxSubmissionCost,
        uint256 _gasLimit,
        uint256 _gasPriceBid
    ) external payable returns (uint256);

    function addERC20LiquidityToL3(
        address _token,
        uint256 _marketId,
        bool _isLong, // LongReserveToken or ShortReserveToken
        uint256 _addAmount,
        uint256 _maxSubmissionCost,
        uint256 _gasLimit,
        uint256 _gasPriceBid
    ) external payable returns (uint256);

    function _removeEthLiquidityFromOutbox(
        address _recipient,
        uint256 _amount
    ) external;

    function _removeERC20LiquidityFromOutbox(
        address _recipient,
        uint256 _amount,
        address _token
    ) external;
}
