// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../common/constants.sol";
import "../utils/MathUtils.sol";

import "../account/TraderVault.sol";
import "../price/PriceManager.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";
import "../order/OrderExecutor.sol";
import "../order/OrderUtils.sol";
import "../orderbook/OrderBook.sol";
import "../token/RISE.sol";

contract Liquidation {
    PriceManager public priceManager;
    TraderVault public traderVault;
    TokenInfo public tokenInfo;
    Market public market;
    OrderExecutor public orderExecutor;
    OrderBook public orderBook;
    RISE public rise;

    using MathUtils for uint256;

    mapping(uint256 => uint256) maintenanceMarginRatioInBasisPoints; // assetId => maintenanceMarginRatio
    uint256 maintenanceMarginRatioPrecision = 1e18;
    uint256 public constant BASIS_POINTS_PRECISION = 1e4;

    constructor(
        address _priceManager,
        address _traderVault,
        address _tokenInfo,
        address _market,
        address _orderExecutor,
        address _orderBook,
        address _RISE
    ) {
        priceManager = PriceManager(_priceManager);
        traderVault = TraderVault(_traderVault);
        tokenInfo = TokenInfo(_tokenInfo);
        market = Market(_market);
        orderExecutor = OrderExecutor(_orderExecutor);
        orderBook = OrderBook(_orderBook);
        rise = RISE(_RISE);
    }

    function executeLiquidations(
        OpenPosition[] calldata _positions,
        address[] calldata _traders
    ) external {
        for (uint256 i = 0; i < _positions.length; i++) {
            liquidatePosition(_positions[i]);
        }
        for (uint256 i = 0; i < _traders.length; i++) {
            liquidateTrader(_traders[i]);
        }
    }

    function liquidatePosition(OpenPosition memory _position) internal {
        orderExecutor.ExecuteCloseOrder(_position);
        orderBook.executeLimitOrders(_position.isLong, _position.marketId);
        //Long position liq -> price buffer downwards -> execute long limit orders
        rise.mintRISE(_position.trader, _position.margin);
        //mint RISE as same size as margin lost


    }

    function liquidateTrader(address _trader) internal {
        (OpenPosition[] memory p, uint256 c) =traderVault.getTraderHotOpenPosition(_trader);
        for (uint256 i = 0; i < c; i++) {
            liquidatePosition(p[i]);
        }
    }

    function _isPositionLiquidationValid(
        OpenPosition calldata _position
    ) internal view returns (bool) {
        uint256 baseAssetId = market
            .getMarketInfo(_position.marketId)
            .baseAssetId;
        //uint256 tokenPrecision = 10 ** tokenInfo.getTokenDecimals(baseAssetId);
        (uint256 lefthandSide, uint256 righthandSide) = _calculateFormula(
            _position
        );
        return _position.margin + lefthandSide < righthandSide;
    }

    function _isTraderLiquidationValid(
        address _trader
    ) internal view returns (bool) {
        // TODO : getWalletBalance 구현 필요
        // uint256 lefthandSide = traderVault.getWalletBalance(_trader);
        uint256 lefthandSide = 0; // 임시
        uint256 righthandSide = 0;
        // TODO : getTraderPositions 구현 필요
        // Position[] memory positions = traderVault.getTraderPositions(_trader);
        OpenPosition[] memory positions; // 임시
        for (uint256 i = 0; i < positions.length; i++) {
            uint256 baseAssetId = market
                .getMarketInfo(positions[i].marketId)
                .baseAssetId;
            (
                uint256 lefthandSideDelta,
                uint256 righthandSideDelta
            ) = _calculateFormula(positions[i]);
            lefthandSide += lefthandSideDelta;
            righthandSide += righthandSideDelta;
        }
        return lefthandSide < righthandSide;
    }

    function _calculateFormula(
        OpenPosition memory _position // Memory 로 해야 하는가?
    ) internal view returns (uint256, uint256) {
        uint256 baseAssetId = market
            .getMarketInfo(_position.marketId)
            .baseAssetId;
        uint256 SP = 10 ** tokenInfo.getTokenDecimals(baseAssetId);
        uint256 RP = BASIS_POINTS_PRECISION;
        uint256 p1 = _position.isLong
            ? priceManager.getMarkPrice(baseAssetId)
            : _position.avgOpenPrice;
        uint256 p2 = _position.isLong
            ? _position.avgOpenPrice
            : priceManager.getMarkPrice(baseAssetId);
        uint256 lefthandSide = p1.mulDiv(_position.size, SP);
        uint256 righthandSide = p2.mulDiv(_position.size, SP) +
            priceManager
                .getMarkPrice(baseAssetId)
                .mulDiv(_position.size, SP)
                .mulDiv(maintenanceMarginRatioInBasisPoints[baseAssetId], RP) +
            priceManager
                .getIndexPrice(baseAssetId)
                .mulDiv(_position.size, SP)
                .mulDiv(_position.size, SP)
                .mulDiv(
                    tokenInfo.getSizeToPriceBufferDeltaMultiplier(baseAssetId),
                    SIZE_TO_PRICE_BUFFER_PRECISION
                ) /
            2;
        return (lefthandSide, righthandSide);

        //liquidation price validation based on maintenance margin -> No longer used - 08/30 Cheolmin
    }
    // _calculation model with maintenance margin: Not using anymore - 08/30 Cheolmin

    // function _executeLiquidation() internal {
    //     // Close all positions
    // }
}

/*
    // Only isolated mode
    // TODO: build for cross mode
    function getLiquidationPrice(
        OpenPosition calldata _position,
        uint256 _walletBalance
    ) public view returns (uint256) {
        uint256 baseAssetId = market
            .getMarketInfo(_position.marketId)
            .baseAssetId;
        uint256 indexPrice = priceManager.getIndexPrice(baseAssetId);
        uint256 size = _position.size;
        uint256 MMR = maintenanceMarginRatioInBasisPoints[baseAssetId];

        uint256 TOKEN_SIZE_PRECISION = 10 **
            tokenInfo.getTokenDecimals(baseAssetId);

        if (_position.isLong) {
            return
                (((BASIS_POINTS_PRECISION / 2 - MMR) * indexPrice * (size ** 2)) /
                    TOKEN_SIZE_PRECISION /
                    PRICE_BUFFER_DELTA_TO_SIZE +
                    _position.avgOpenPrice *
                    size *
                    BASIS_POINTS_PRECISION -
                    _walletBalance *
                    TOKEN_SIZE_PRECISION *
                    BASIS_POINTS_PRECISION) /
                (BASIS_POINTS_PRECISION - MMR) /
                size;
        } else {
            return
                (_position.avgOpenPrice *
                    size *
                    BASIS_POINTS_PRECISION +
                    _walletBalance *
                    TOKEN_SIZE_PRECISION *
                    BASIS_POINTS_PRECISION -
                    ((BASIS_POINTS_PRECISION / 2 + MMR) * indexPrice * (size ** 2)) /
                    TOKEN_SIZE_PRECISION /
                    PRICE_BUFFER_DELTA_TO_SIZE) /
                (BASIS_POINTS_PRECISION + MMR) /
                size;
        }
    }

    function shouldLiquidate(
        OpenPosition calldata _position,
        uint256 _walletBalance
    ) public view returns (bool) {
        uint256 baseAssetId = market
            .getMarketInfo(_position.marketId)
            .baseAssetId;
        uint256 markPrice = priceManager.getMarkPrice(baseAssetId);
        if (_position.isLong) {
            return markPrice < getLiquidationPrice(_position, _walletBalance);
        } else {
            return markPrice > getLiquidationPrice(_position, _walletBalance);
        }
    }
}
*/
