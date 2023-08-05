// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/l2/IInbox.sol";
import "./interfaces/l3/IL3Gateway.sol";

import "../common/structs.sol";
import "../common/params.sol";

import "../risepool/RisePoolUtils.sol";
import "../market/Market.sol";
import "./TransferHelper.sol";
import "../token/RM.sol";

contract L2LiquidityGateway is TransferHelper {
    address public l3GatewayAddress;
    RisePoolUtils public risePoolUtils;
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

    // TODO: integration test
    function addEthLiquidityToL3(
        uint256 _marketId,
        bool _isLongReserve,
        uint256 _addAmount,
        L2ToL3FeeParams memory p
    ) external payable returns (uint256) {
        require(_addAmount > 0, "L2Gateway: deposit amount should be positive");
        require(
            msg.value >=
                _addAmount +
                    p._maxSubmissionCost +
                    p._gasLimit *
                    p._gasPriceBid,
            "L2Gateway: insufficient msg.value"
        );

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.addLiquidity.selector,
            _marketId,
            _isLongReserve,
            _addAmount
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
            msg.value -
                (_addAmount +
                    p._maxSubmissionCost +
                    p._gasLimit *
                    p._gasPriceBid)
        );

        // mint $RM tokens

        MarketInfo memory marketInfo = market.getMarketInfo(_marketId);
        RiseMarketMaker rm = RiseMarketMaker(marketInfo.marketMakerToken);
        uint256 mintAmount = risePoolUtils.getMintAmount(); // TODO: calculate AUM of MM pool & calculate the mint amount of $RM tokens

        rm.mint(msg.sender, mintAmount);

        return ticketId;
    }

    function addERC20LiquidityToL3(
        address _token,
        uint256 _marketId,
        bool _isLongReserve,
        uint256 _addAmount,
        L2ToL3FeeParams memory p
    ) external payable returns (uint256) {
        require(_addAmount > 0, "L2Gateway: deposit amount should be positive");
        require(
            msg.value >= p._maxSubmissionCost + p._gasLimit * p._gasPriceBid,
            "L2Gateway: insufficient msg.value"
        );

        // MarketInfo memory marketInfo = market.getMarketInfo(_marketId);
        // TODO: check if marketId matches the token address

        _transferIn(msg.sender, _token, _addAmount);

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.addLiquidity.selector,
            _marketId,
            _isLongReserve,
            _addAmount
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

        // mint $RM tokens

        MarketInfo memory marketInfo = market.getMarketInfo(_marketId);
        RiseMarketMaker rm = RiseMarketMaker(marketInfo.marketMakerToken);
        uint256 mintAmount = risePoolUtils.getMintAmount(); // TODO: calculate AUM of MM pool & calculate the mint amount of $RM tokens

        rm.mint(msg.sender, mintAmount);

        return ticketId;
    }

    // -------------------- L2 -> L3 -> L2 Messaging --------------------
    // path: L2 => Retryable => L3 withdraw => ArbSys => Outbox
    // Outflow (remove liquidity)

    function triggerRemoveLiquidityFromL2(
        uint256 _marketId,
        bool _isLongReserve,
        uint256 _withdrawAmount,
        L2ToL3FeeParams memory p
    ) external payable returns (uint256) {
        // TODO: check - 호출 순서 확인 및 Retryable redeem 실패 시 다시 $RM mint 가능한지 확인
        MarketInfo memory marketInfo = market.getMarketInfo(_marketId);

        // burn $RM tokens
        RiseMarketMaker rm = RiseMarketMaker(marketInfo.marketMakerToken);
        rm.burn(msg.sender, _withdrawAmount);

        bytes memory data = abi.encodeWithSelector(
            IL3Gateway.removeLiquidityToL2.selector,
            _marketId,
            _isLongReserve,
            msg.sender, // recipient restricted to msg.sender
            _withdrawAmount
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
    function _removeEthLiquidityFromOutbox(
        address _recipient,
        uint256 _amount
    ) external {
        if (!allowedBridgesMap[msg.sender].allowed)
            revert NotBridge(msg.sender);

        _transferEth(payable(_recipient), _amount);
    }

    /**
     * @notice restricted to be called by the allowed L2 Bridges
     */
    function _removeERC20LiquidityFromOutbox(
        address _recipient,
        uint256 _amount,
        address _token
    ) external {
        if (!allowedBridgesMap[msg.sender].allowed)
            revert NotBridge(msg.sender);

        _transferOut(_token, _amount, _recipient);
    }
}
