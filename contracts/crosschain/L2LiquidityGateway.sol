// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/l2/IInbox.sol";
import "./interfaces/l3/IL3Gateway.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";
import "../token/RMM.sol";
import "../risepool/RisePoolUtils.sol";
import "./TransferHelper.sol";
import "../common/Constants.sol";

contract L2LiquidityGateway is TransferHelper, Constants {
    address public l3GatewayAddress;
    RisePoolUtils public risePoolUtils;
    TokenInfo public tokenInfo;
    Market public market;
    IInbox public inbox;

    error NotBridge(address sender); // TODO: move to errors

    struct InOutInfo {
        uint256 index;
        bool allowed;
    }

    mapping(address => InOutInfo) private allowedBridgesMap;

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

    // ----------------------- L2 -> L3 Messaging -----------------------
    // Inflow (add Liquidity)

    // TODO: mint $RMM tokens
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

        // mint $RMM tokens

        Market.MarketInfo memory marketInfo = market.getMarketInfo(_marketId);
        RiseMarketMaker rmm = RiseMarketMaker(marketInfo.marketMakerToken);

        uint256 mintAmount = risePoolUtils.getMintAmount(); // TODO: calculate AUM of MM pool & calculate the mint amount of $RMM tokens

        rmm.mint(msg.sender, mintAmount);

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
    // Outflow (remove liquidity)

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
