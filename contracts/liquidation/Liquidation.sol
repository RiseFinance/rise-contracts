// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../common/constants.sol";
import "../oracle/PriceManager.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";
import "../common/MathUtils.sol";
import "../account/TraderVault.sol";

contract Liquidation {
    mapping(uint256 => uint256) maintenanceMarginRatioInBasisPoints; // assetId => maintenanceMarginRatio
    uint256 maintenanceMarginRatioPrecision = 1e18;
    uint256 public constant BASIS_POINTS = 1e4;
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
        Position[] calldata _positions,
        address[] calldata _traders
    ) external {
        for (uint256 i = 0; i < _positions.length; i++) {
            liquidatePosition(_positions[i]);
        }
        for (uint256 i = 0; i < _traders.length; i++) {
            liquidateTrader(_traders[i]);
        }
    }

    function liquidatePosition(Position calldata _position) internal {
        if (!_isPositionLiquidationValid(_position)) return;
        // TODO: liquidate Position
    }

    function liquidateTrader(address _trader) internal {
        if (!_isTraderLiquidationValid(_trader)) return;
        // TODO: liquidate all positions of trader
    }

    function _isPositionLiquidationValid(
        Position calldata _position
    ) internal returns (bool) {
        uint256 baseAssetId = market
            .getMarketInfo(_position.marketId)
            .baseAssetId;
        uint256 tokenPrecision = 10 ** tokenInfo.getTokenDecimals(baseAssetId);
        (uint256 lefthandSide, uint256 righthandSide) = _calculateFormula(
            priceManager.getMarkPrice(baseAssetId),
            priceManager.getIndexPrice(baseAssetId),
            _position.avgOpenPrice,
            _position.size,
            _position.isLong,
            maintenanceMarginRatioInBasisPoints[baseAssetId],
            PRICE_BUFFER_DELTA_TO_SIZE,
            tokenPrecision,
            BASIS_POINTS
        );
        return _position.margin + lefthandSide < righthandSide;
    }

    function _isTraderLiquidationValid(
        address _trader
    ) internal returns (bool) {
        // TODO : getWalletBalance 구현 필요
        // uint256 lefthandSide = traderVault.getWalletBalance(_trader);
        uint256 lefthandSide = 0; // 임시
        uint256 righthandSide = 0;
        // TODO : getTraderPositions 구현 필요
        // Position[] memory positions = traderVault.getTraderPositions(_trader);
        Position[] memory positions; // 임시
        for (uint256 i = 0; i < positions.length; i++) {
            uint256 baseAssetId = market
                .getMarketInfo(positions[i].marketId)
                .baseAssetId;
            (
                uint256 lefthandSideDelta,
                uint256 righthandSideDelta
            ) = _calculateFormula(
                    priceManager.getMarkPrice(baseAssetId),
                    priceManager.getIndexPrice(baseAssetId),
                    positions[i].avgOpenPrice,
                    positions[i].size,
                    positions[i].isLong,
                    maintenanceMarginRatioInBasisPoints[baseAssetId],
                    PRICE_BUFFER_DELTA_TO_SIZE,
                    10 ** tokenInfo.getTokenDecimals(baseAssetId),
                    BASIS_POINTS
                );
            lefthandSide += lefthandSideDelta;
            righthandSide += righthandSideDelta;
        }
        return lefthandSide < righthandSide;
    }

    function _calculateFormula(
        uint256 p,
        uint256 pi,
        uint256 pe,
        uint256 s,
        bool isLong,
        uint256 r,
        uint256 c,
        uint256 SP,
        uint256 RP
    ) internal pure returns (uint256, uint256) {
        uint256 p1 = isLong ? p : pe;
        uint256 p2 = isLong ? pe : p;
        uint256 lefthandSide = mulDiv(p1, s, SP);
        uint256 righthandSide = mulDiv(p2, s, SP) +
            mulDiv(mulDiv(p, s, SP), r, RP) +
            mulDiv(mulDiv(pi, s, SP), s, SP) /
            c /
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
        Position calldata _position,
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
                (((BASIS_POINTS / 2 - MMR) * indexPrice * (size ** 2)) /
                    TOKEN_SIZE_PRECISION /
                    PRICE_BUFFER_DELTA_TO_SIZE +
                    _position.avgOpenPrice *
                    size *
                    BASIS_POINTS -
                    _walletBalance *
                    TOKEN_SIZE_PRECISION *
                    BASIS_POINTS) /
                (BASIS_POINTS - MMR) /
                size;
        } else {
            return
                (_position.avgOpenPrice *
                    size *
                    BASIS_POINTS +
                    _walletBalance *
                    TOKEN_SIZE_PRECISION *
                    BASIS_POINTS -
                    ((BASIS_POINTS / 2 + MMR) * indexPrice * (size ** 2)) /
                    TOKEN_SIZE_PRECISION /
                    PRICE_BUFFER_DELTA_TO_SIZE) /
                (BASIS_POINTS + MMR) /
                size;
        }
    }

    function shouldLiquidate(
        Position calldata _position,
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
