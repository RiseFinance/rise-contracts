// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../common/constants.sol";
import "../oracle/PriceManager.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";

contract Liquidation {
    mapping(uint256 => uint256) maintenanceMarginRatioInBasisPoints; // assetId => maintenanceMarginRatio
    uint256 maintenanceMarginRatioPrecision = 1e18;
    uint256 public constant BASIS_POINTS = 1e4;
    PriceManager public priceManager;
    TokenInfo public tokenInfo;
    Market public market;

    function executeLiquidationIfNeeded(
        Position calldata _position,
        uint256 _walletBalance
    ) external {
        if (shouldLiquidate(_position, _walletBalance)) {
            _executeLiquidation();
        }
    }

    function _executeLiquidation() internal {
        // Close all positions
    }

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
            tokenInfo.tokenDecimals(baseAssetId);

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
