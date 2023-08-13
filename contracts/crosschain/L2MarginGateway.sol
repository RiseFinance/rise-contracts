// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/l2/IInbox.sol";
import "./interfaces/l3/IL3Gateway.sol";

import "../common/params.sol";

import "../market/TokenInfo.sol";
import "./TransferHelper.sol";
import "./L2Vault.sol";
import {ETH_ID} from "../common/constants.sol";

contract L2MarginGateway is TransferHelper {
    error NotBridge(address sender); // TODO: move to errors

    struct InOutInfo {
        uint256 index;
        bool allowed;
    }

    address public l3GatewayAddress;
    TokenInfo public tokenInfo;
    L2Vault public l2Vault;
    IInbox public inbox;

    mapping(address => InOutInfo) public allowedBridgesMap;

    // event RetryableTicketCreated(uint256 indexed ticketId);

    constructor(address _inbox, address _l2Vault, address _tokenInfo) {
        inbox = IInbox(_inbox);
        l2Vault = L2Vault(_l2Vault);
        tokenInfo = TokenInfo(_tokenInfo);
    }

    function initialize(address _l3GatewayAddress) external {
        require(
            l3GatewayAddress == address(0),
            "L2Gateway: already initialized"
        );
        l3GatewayAddress = _l3GatewayAddress;
    }

    function setAllowedBridge(address _allowedBridge) external {
        // only owner
        require(
            allowedBridgesMap[_allowedBridge].index == 0,
            "L2Gateway: already allowed"
        );
        allowedBridgesMap[_allowedBridge].allowed = true;
    }

    // ----------------------- L2 -> L3 Messaging -----------------------
    // Inflow (deposit)
    // TODO: deposit & withdraw ERC-20 (SafeERC20)
    // TODO: gas fee calculation & L3 gas fee funding

    /**
     * @dev `msg.value` should include
     * 1) the ETH deposit amount for the Rise Finance L3 application
     * 2) cost of submitting and executing the retryable ticket, which is `l3CallValue + maxSubmissionCost + gasLimit * gasPriceBid`
     *    here, l3CallValue is always zero (not allowing ETH or ERC-20 token representations of traders balances to be minted in L3)
     *
     * @param _depositAmount amount of ETH to deposit
     * @param p._maxSubmissionCost the maximum amount of ETH to be paid for submitting the retryable ticket
     * @param p._gasLimit the maximum amount of gas used to cover L3 execution of the ticket
     * @param p._gasPriceBid the gas price bid for L3 execution of the ticket
     * @return ticketId the unique id of the retryable ticket created
     */
    function depositEthToL3(
        uint256 _depositAmount,
        L2ToL3FeeParams memory p
    ) external payable returns (uint256) {
        require(
            _depositAmount > 0,
            "L2Gateway: deposit amount should be positive"
        );
        require(
            msg.value >=
                _depositAmount +
                    p._maxSubmissionCost +
                    p._gasLimit *
                    p._gasPriceBid,
            "L2Gateway: insufficient msg.value"
        );

        // transfer ETH to L2Vault
        _transferEth(payable(address(l2Vault)), _depositAmount); // TODO: check if `payable` is necessary

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.increaseTraderBalance.selector,
            msg.sender, // _trader
            ETH_ID, // _assetId
            _depositAmount // _amount
        );

        // with no custom ArbSys withdraw function, the deposit amount must be held in L2Gateway
        // and only Ticket process fees would be sent to the Bridge via Inbox
        uint256 ticketId = inbox.createRetryableTicket{
            value: p._maxSubmissionCost + p._gasLimit * p._gasPriceBid
        }(
            l3GatewayAddress,
            0, // l3CallValue
            p._maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // TODO: aggregate excess fees on a L3 admin contract (not msg.sender)
            msg.sender, // callValueRefundAddress
            p._gasLimit,
            p._gasPriceBid,
            data
        );

        // refund excess ETH
        _transferEth(
            payable(msg.sender),
            msg.value -
                (_depositAmount +
                    p._maxSubmissionCost +
                    p._gasLimit *
                    p._gasPriceBid)
        );
        // TODO: refund excess gas fee after processing the ticket

        // emit RetryableTicketCreated(ticketId);
        return ticketId;
    }

    function depositERC20ToL3(
        address _token,
        uint256 _depositAmount,
        L2ToL3FeeParams memory p
    ) external payable returns (uint256) {
        require(
            _depositAmount > 0,
            "L2Gateway: deposit amount should be positive"
        );
        require(
            msg.value >= p._maxSubmissionCost + p._gasLimit * p._gasPriceBid,
            "L2Gateway: insufficient msg.value"
        );

        l2Vault._transferInERC20ToL2Vault(msg.sender, _token, _depositAmount);

        uint256 assetId = tokenInfo.getAssetIdFromTokenAddress(_token);

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.increaseTraderBalance.selector,
            msg.sender, // _trader
            assetId, // _assetId
            _depositAmount // _amount
        );

        uint256 ticketId = inbox.createRetryableTicket{
            value: p._maxSubmissionCost + p._gasLimit * p._gasPriceBid
        }(
            l3GatewayAddress,
            0, // l3CallValue
            p._maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // TODO: aggregate excess fees on a L3 admin contract (not msg.sender)
            msg.sender, // callValueRefundAddress
            p._gasLimit,
            p._gasPriceBid,
            data
        );

        // refund excess ETH
        _transferEth(
            payable(msg.sender),
            msg.value - (p._maxSubmissionCost + p._gasLimit * p._gasPriceBid)
        );

        return ticketId;
    }

    // -------------------- L2 -> L3 -> L2 Messaging --------------------
    // path: L2 => Retryable => L3 withdraw => ArbSys => Outbox
    // Outflow (withdraw)

    // FIXME: cross mode PnL까지 고려해서 withdraw max cap 지정 (require)
    function triggerWithdrawalFromL2(
        uint256 _assetId,
        uint256 _withdrawAmount,
        L2ToL3FeeParams memory p
    ) external payable returns (uint256) {
        // minimal validation should be conducted from frontend (check L3Vault.traderBalances)

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.withdrawAssetToL2.selector,
            msg.sender, // _trader => cannot modify the recipient address
            _assetId, // _assetId
            _withdrawAmount // _amount
        );

        uint256 ticketId = inbox.createRetryableTicket{
            value: p._maxSubmissionCost + p._gasLimit * p._gasPriceBid
        }(
            l3GatewayAddress,
            0,
            p._maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // TODO: aggregate excess fees on a L3 admin contract (not msg.sender)
            msg.sender, // callValueRefundAddress
            p._gasLimit,
            p._gasPriceBid,
            data
        );

        return ticketId;
    }

    /**
     * @notice restricted to be called by the allowed L2 Bridges
     */
    function _withdrawEthFromOutbox(
        address _recipient,
        uint256 _amount
    ) external {
        // call: L3 ArbSys.sendTxToL1 => Oubox.executeTransaction => Bridge.executeCall => L2Gateway.withdrawEthFromOutbox
        // Not allowed to called directly

        // require(tx.origin == _recipient); // cannot delegate the execution to keepers with this condition

        if (!allowedBridgesMap[msg.sender].allowed)
            revert NotBridge(msg.sender);

        l2Vault._transferOutEthFromL2Vault(payable(_recipient), _amount);
    }

    /**
     * @notice restricted to be called by the allowed L2 Bridges
     */
    function _withdrawERC20FromOutbox(
        address _recipient,
        uint256 _amount,
        address _token
    ) external {
        if (!allowedBridgesMap[msg.sender].allowed)
            revert NotBridge(msg.sender);

        l2Vault._transferOutERC20FromL2Vault(_token, _amount, _recipient);
    }
}
