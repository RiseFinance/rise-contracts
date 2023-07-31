// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/l2/IInbox.sol";
import "./interfaces/l2/IL2Gateway.sol";
import "./interfaces/l3/IL3Gateway.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";
import "./TransferHelper.sol";

contract L2Gateway is IL2Gateway, TransferHelper {
    address public l3GatewayAddress;
    TokenInfo public tokenInfo;
    Market public market;
    IInbox public inbox;

    error NotBridge(address sender); // TODO: move to errors

    struct InOutInfo {
        uint256 index;
        bool allowed;
    }

    mapping(address => InOutInfo) private allowedBridgesMap;

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

    // -------------------- L2 -> L3 Messaging --------------------
    // Inflow
    // Deposit & Add Liquidity
    // TODO: deposit & withdraw ERC-20 (SafeERC20)
    // TODO: gas fee calculation & L3 gas fee funding

    /**
     * @dev `msg.value` should include
     * 1) the ETH deposit amount for the Rise Finance L3 application
     * 2) cost of submitting and executing the retryable ticket, which is `l3CallValue + maxSubmissionCost + gasLimit * gasPriceBid`
     *    here, l3CallValue is always zero (not allowing ETH or ERC-20 token representations of traders balances to be minted in L3)
     *
     * @param _depositAmount amount of ETH to deposit
     * @param _maxSubmissionCost the maximum amount of ETH to be paid for submitting the retryable ticket
     * @param _gasLimit the maximum amount of gas used to cover L3 execution of the ticket
     * @param _gasPriceBid the gas price bid for L3 execution of the ticket
     * @return ticketId the unique id of the retryable ticket created
     */
    function depositEthToL3(
        uint256 _depositAmount,
        uint256 _maxSubmissionCost,
        uint256 _gasLimit,
        uint256 _gasPriceBid
    ) external payable returns (uint256) {
        require(
            _depositAmount > 0,
            "L2Gateway: deposit amount should be positive"
        );
        require(
            msg.value >=
                _depositAmount + _maxSubmissionCost + _gasLimit * _gasPriceBid,
            "L2Gateway: insufficient msg.value"
        );

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.increaseTraderBalance.selector,
            msg.sender, // _trader
            ETH_ID, // _assetId
            _depositAmount // _amount
        );

        // with no custom ArbSys withdraw function, the deposit amount must be held in L2Gateway
        // and only Ticket process fees would be sent to the Bridge via Inbox
        uint256 ticketId = inbox.createRetryableTicket{
            value: _maxSubmissionCost + _gasLimit * _gasPriceBid
        }(
            l3GatewayAddress,
            0, // l3CallValue
            _maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // TODO: aggregate excess fees on a L3 admin contract (not msg.sender)
            msg.sender, // callValueRefundAddress
            _gasLimit,
            _gasPriceBid,
            data
        );

        // refund excess ETH
        _transferEth(
            payable(msg.sender),
            msg.value -
                (_depositAmount + _maxSubmissionCost + _gasLimit * _gasPriceBid)
        );
        // TODO: refund excess gas fee after processing the ticket

        // emit RetryableTicketCreated(ticketId);
        return ticketId;
    }

    function depositERC20ToL3(
        address _token,
        uint256 _depositAmount,
        uint256 _maxSubmissionCost,
        uint256 _gasLimit,
        uint256 _gasPriceBid
    ) external payable returns (uint256) {
        require(
            _depositAmount > 0,
            "L2Gateway: deposit amount should be positive"
        );
        require(
            msg.value >= _maxSubmissionCost + _gasLimit * _gasPriceBid,
            "L2Gateway: insufficient msg.value"
        );

        _transferIn(msg.sender, _token, _depositAmount);

        uint256 tokenId = tokenInfo.getTokenIdFromAddress(_token);

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.increaseTraderBalance.selector,
            msg.sender, // _trader
            tokenId, // _assetId
            _depositAmount // _amount
        );

        uint256 ticketId = inbox.createRetryableTicket{
            value: _maxSubmissionCost + _gasLimit * _gasPriceBid
        }(
            l3GatewayAddress,
            0, // l3CallValue
            _maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // TODO: aggregate excess fees on a L3 admin contract (not msg.sender)
            msg.sender, // callValueRefundAddress
            _gasLimit,
            _gasPriceBid,
            data
        );

        // refund excess ETH
        _transferEth(
            payable(msg.sender),
            msg.value - (_maxSubmissionCost + _gasLimit * _gasPriceBid)
        );

        return ticketId;
    }

    // TODO: mint $RLP tokens
    // TODO: liquidity - ETH & ERC20
    // TODO: integration test
    function addEthLiquidityToL3(
        uint256 _marketId,
        bool _isLong, // LongReserveToken or ShortReserveToken
        uint256 _addAmount,
        uint256 _maxSubmissionCost,
        uint256 _gasLimit,
        uint256 _gasPriceBid
    ) external payable returns (uint256) {
        require(_addAmount > 0, "L2Gateway: deposit amount should be positive");
        require(
            msg.value >=
                _addAmount + _maxSubmissionCost + _gasLimit * _gasPriceBid,
            "L2Gateway: insufficient msg.value"
        );

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.addLiquidity.selector,
            _marketId,
            _isLong,
            _addAmount
        );

        uint256 ticketId = inbox.createRetryableTicket{
            value: _maxSubmissionCost + _gasLimit * _gasPriceBid
        }(
            l3GatewayAddress,
            0, // l3CallValue
            _maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // TODO: aggregate excess fees on a L3 admin contract (not msg.sender)
            msg.sender, // callValueRefundAddress
            _gasLimit,
            _gasPriceBid,
            data
        );

        // refund excess ETH
        _transferEth(
            payable(msg.sender),
            msg.value -
                (_addAmount + _maxSubmissionCost + _gasLimit * _gasPriceBid)
        );

        return ticketId;
    }

    function addERC20LiquidityToL3(
        address _token,
        uint256 _marketId,
        bool _isLong, // LongReserveToken or ShortReserveToken
        uint256 _addAmount,
        uint256 _maxSubmissionCost,
        uint256 _gasLimit,
        uint256 _gasPriceBid
    ) external payable returns (uint256) {
        require(_addAmount > 0, "L2Gateway: deposit amount should be positive");
        require(
            msg.value >= _maxSubmissionCost + _gasLimit * _gasPriceBid,
            "L2Gateway: insufficient msg.value"
        );

        // Market.MarketInfo memory marketInfo = market.getMarketInfo(_marketId);
        // TODO: check if marketId matches the token address

        _transferIn(msg.sender, _token, _addAmount);

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.addLiquidity.selector,
            _marketId,
            _isLong,
            _addAmount
        );

        uint256 ticketId = inbox.createRetryableTicket{
            value: _maxSubmissionCost + _gasLimit * _gasPriceBid
        }(
            l3GatewayAddress,
            0, // l3CallValue
            _maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // TODO: aggregate excess fees on a L3 admin contract (not msg.sender)
            msg.sender, // callValueRefundAddress
            _gasLimit,
            _gasPriceBid,
            data
        );

        // refund excess ETH
        _transferEth(
            payable(msg.sender),
            msg.value - (_maxSubmissionCost + _gasLimit * _gasPriceBid)
        );

        return ticketId;
    }

    // -------------------- L2 -> L3 -> L2 Messaging --------------------
    // path: L2 => Retryable => L3 withdraw => ArbSys => Outbox
    // Outflow
    // Withdraw & Remove Liquidity

    // FIXME: cross mode PnL까지 고려해서 withdraw max cap 지정 (require)
    function triggerWithdrawalFromL2(
        uint256 _withdrawAmount,
        uint256 _maxSubmissionCost,
        uint256 _gasLimit,
        uint256 _gasPriceBid
    ) external payable returns (uint256) {
        // minimal validation should be conducted from frontend (check L3Vault.traderBalances)

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.withdrawEthToL2.selector,
            msg.sender, // _trader => cannot modify the recipient address
            _withdrawAmount // _amount
        );

        uint256 ticketId = inbox.createRetryableTicket{
            value: _maxSubmissionCost + _gasLimit * _gasPriceBid
        }(
            l3GatewayAddress,
            0,
            _maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress // TODO: aggregate excess fees on a L3 admin contract (not msg.sender)
            msg.sender, // callValueRefundAddress
            _gasLimit,
            _gasPriceBid,
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

        _transferEth(payable(_recipient), _amount);
    }

    /**
     * @notice restricted to be called by the allowed L2 Bridges
     */
    function _removeEthLiquidityFromOutbox(
        address _recipient,
        uint256 _amount
    ) external {
        if (!allowedBridgesMap[msg.sender].allowed)
            revert NotBridge(msg.sender);

        _transferEth(payable(_recipient), _amount);
    }
}
