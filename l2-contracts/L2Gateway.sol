// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IInbox.sol";
import "../contracts/interfaces/IL3Gateway.sol";
import "../contracts/TransferHelper.sol";

contract L2Gateway is TransferHelper {
    error NotBridge(address sender); // TODO: move to errors

    struct InOutInfo {
        uint256 index;
        bool allowed;
    }

    mapping(address => InOutInfo) private allowedBridgesMap;

    address public l3GatewayAddress;
    IInbox public inbox;

    uint256 public constant ETH_ID = 1; // TODO: move to constants

    // event RetryableTicketCreated(uint256 indexed ticketId);

    constructor(address _inboxAddress) {
        inbox = IInbox(_inboxAddress);
    }

    function initialize(address _l3GatewayAddress) external {
        require(
            l3GatewayAddress == address(0),
            "L2Gateway: already initialized"
        );
        l3GatewayAddress = _l3GatewayAddress;
    }

    /**
     * @dev `msg.value` should include
     * 1) the ETH deposit amount for the Rise Finance L3 application
     * 2) cost of submitting and executing the retryable ticket, which is `l3CallValue + maxSubmissionCost + gasLimit * gasPriceBid`
     *    here, l3CallValue is always zero (not allowing ETH or ERC-20 token representations of traders balances to be minted in L3)
     *
     * @param depositAmount amount of ETH to deposit
     * @param maxSubmissionCost the maximum amount of ETH to be paid for submitting the retryable ticket
     * @param gasLimit the maximum amount of gas used to cover L3 execution of the ticket
     * @param gasPriceBid the gas price bid for L3 execution of the ticket
     * @return ticketId the unique id of the retryable ticket created
     */
    function depositEthToL3(
        uint256 depositAmount,
        uint256 maxSubmissionCost,
        uint256 gasLimit,
        uint256 gasPriceBid
    ) external payable returns (uint256) {
        require(
            depositAmount > 0,
            "L2Gateway: deposit amount should be positive"
        );
        require(
            msg.value >=
                depositAmount + maxSubmissionCost + gasLimit * gasPriceBid,
            "L2Gateway: insufficient msg.value"
        );

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.increaseTraderBalance.selector,
            msg.sender, // _trader
            ETH_ID, // _assetId
            depositAmount // _amount
        );

        // with no custom ArbSys withdraw function, the deposit amount must be held in L2Gateway
        // and only Ticket process fees would be sent to the Bridge via Inbox
        uint256 ticketId = inbox.createRetryableTicket{
            value: maxSubmissionCost + gasLimit * gasPriceBid
        }(
            l3GatewayAddress,
            0, // l3CallValue
            maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // TODO: aggregate excess fees on a L3 admin contract (not msg.sender)
            msg.sender, // callValueRefundAddress
            gasLimit,
            gasPriceBid,
            data
        );

        // refund excess ETH
        _transferEth(
            payable(msg.sender),
            msg.value -
                (depositAmount + maxSubmissionCost + gasLimit * gasPriceBid)
        );
        // TODO: refund excess gas fee after processing the ticket

        // emit RetryableTicketCreated(ticketId);
        return ticketId;
    }

    /**
     * @notice restricted to be called by the allowed L2 Bridges
     */
    function withdrawEthFromOutbox(
        address _recipient,
        uint256 _amount
    ) external {
        // call: L3 ArbSys.sendTxToL1 => Oubox.executeTransaction => Bridge.executeCall => L2Gateway.withdrawEthFromOutbox
        // Not allowed to be directly called

        // require(tx.origin == _recipient); // cannot delegate the execution to keepers with this condition

        if (!allowedBridgesMap[msg.sender].allowed)
            revert NotBridge(msg.sender);

        _transferEth(payable(_recipient), _amount);
    }
}
