// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IL2MarginGateway {
    function depositEthToL3(
        uint256 _depositAmount,
        uint256 _maxSubmissionCost,
        uint256 _gasLimit,
        uint256 _gasPriceBid
    ) external payable returns (uint256);

    function depositERC20ToL3(
        address _token,
        uint256 _depositAmount,
        uint256 _maxSubmissionCost,
        uint256 _gasLimit,
        uint256 _gasPriceBid
    ) external payable returns (uint256);

    function _withdrawEthFromOutbox(
        address _recipient,
        uint256 _amount
    ) external;

    function _withdrawERC20FromOutbox(
        address _recipient,
        uint256 _amount,
        address _token
    ) external;
}
