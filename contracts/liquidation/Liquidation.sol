// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../common/constants.sol";
import "../utils/MathUtils.sol";

import "../account/TraderVault.sol";
import "../oracle/PriceManager.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";

contract Liquidation {
    mapping(uint256 => uint256) maintenanceMarginRatioInBasisPoints; // assetId => maintenanceMarginRatio
    uint256 maintenanceMarginRatioPrecision = 1e18;
    uint256 public constant BASIS_POINTS_PRECISION = 1e4;
    PriceManager public priceManager;
    TokenInfo public tokenInfo;
    Market public market;
    TraderVault public traderVault;

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256) {
        return Math.mulDiv(x, y, denominator);
    }

    function executeLiquidations(
        OpenPosition[] calldata _positions,
        address[] calldata _traders
    ) external view {
        for (uint256 i = 0; i < _positions.length; i++) {
            liquidatePosition(_positions[i]);
        }
        for (uint256 i = 0; i < _traders.length; i++) {
            liquidateTrader(_traders[i]);
        }
    }

    function liquidatePosition(OpenPosition calldata _position) internal view {
        if (!_isPositionLiquidationValid(_position)) return;
        // TODO: liquidate Position
        // TODO: @0xjunha
        // market order로 close, 남은 돈은 LP pool로 보내기
    }

    function liquidateTrader(address _trader) internal view {
        if (!_isTraderLiquidationValid(_trader)) return;
        // TODO: liquidate all positions of trader
    }

    function _isPositionLiquidationValid(
        OpenPosition calldata _position
    ) internal view returns (bool) {
        uint256 baseAssetId = market
            .getMarketInfo(_position.marketId)
            .baseAssetId;
        uint256 tokenPrecision = 10 ** tokenInfo.getTokenDecimals(baseAssetId);
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
        uint256 lefthandSide = mulDiv(p1, _position.size, SP);
        uint256 righthandSide = mulDiv(p2, _position.size, SP) +
            mulDiv(
                mulDiv(
                    priceManager.getMarkPrice(baseAssetId),
                    _position.size,
                    SP
                ),
                maintenanceMarginRatioInBasisPoints[baseAssetId],
                RP
            ) +
            mulDiv(
                mulDiv(
                    mulDiv(
                        priceManager.getIndexPrice(baseAssetId),
                        _position.size,
                        SP
                    ),
                    _position.size,
                    SP
                ),
                tokenInfo.getSizeToPriceBufferDeltaMultiplier(baseAssetId),
                SIZE_TO_PRICE_BUFFER_PRECISION
            ) /
            2;
        return (lefthandSide, righthandSide);
    }

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
