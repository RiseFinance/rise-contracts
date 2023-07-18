// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IInbox.sol";
import "../contracts/interfaces/IL3Gateway.sol";

contract L2Gateway {
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
     * @param depositAmount amount of ETH to deposit
     * @param maxSubmissionCost the maximum amount of ETH to be paid for submitting the retryable ticket
     * @param gasLimit the maximum amount of gas used to cover L3 execution of the ticket
     * @param gasPriceBid the gas price bid for L3 execution of the ticket
     *
     * @return ticketId the unique id of the retryable ticket created
     *
     * @dev `msg.value` should include
     * 1) the ETH deposit amount for the Rise Finance L3 application
     * 2) cost of submitting and executing the retryable ticket, which is `l3CallValue + maxSubmissionCost + gasLimit * gasPriceBid`
     *    here, l3CallValue is always zero (not allowing ETH or ERC-20 token representations of traders balances to be minted in L3)
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

        // TODO: decide where the locked tokens should be sent (L2Gateway or Inbox?)
        uint256 ticketId = inbox.createRetryableTicket{
            value: maxSubmissionCost + gasLimit * gasPriceBid
        }(
            l3GatewayAddress,
            0, // l3CallValue
            maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // FIXME: which account should deal with the gas fee?
            msg.sender, // callValueRefundAddress // FIXME: which account should deal with the gas fee?
            gasLimit,
            gasPriceBid,
            data
        );

        // refund excess ETH
        payable(msg.sender).transfer(
            msg.value - (maxSubmissionCost + gasLimit * gasPriceBid)
        );
        // TODO: excess gas fee

        // emit RetryableTicketCreated(ticketId);
        return ticketId;
    }
}
