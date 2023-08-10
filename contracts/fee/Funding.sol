// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../common/structs.sol";
import "../common/constants.sol";

import "../oracle/PriceManager.sol";
import "../global/GlobalState.sol";
import "../order/OrderUtils.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";
import "../utils/MathUtils.sol";

contract Funding {
    using SafeCast for int256;
    using SafeCast for uint256;

    GlobalState public globalState;
    PriceManager public priceManager;
    Market public market;
    TokenInfo public tokenInfo;
    OrderUtils public orderUtils;

    // int256 public constant FUNDING_RATE_CONSTANT = 1;
    int256 public constant FUNDING_RATE_PRECISION = 1e26;
    int256 public interestRate = FUNDING_RATE_PRECISION / 100000 / 3600; // 0.001% per hour
    int256 public fundingRateDamper = FUNDING_RATE_PRECISION / 100000 / 3600; // 0.005% per

    // TODO: FUNDING_RATE_CONSTANT, FUNDING_RATE_PRECISION 값 확인 필요
    mapping(uint256 => int256) latestFundingIndex; // assetId => fundingIndex
    mapping(uint256 => uint256) latestFundingTimestamp; // assetId => timestamp

    function getFundingIndex(uint256 _marketId) public view returns (int256) {
        int256 fundingIndexDelta = getFundingRate(_marketId) *
            (block.timestamp - latestFundingTimestamp[_marketId]).toInt256();
        return latestFundingIndex[_marketId] + fundingIndexDelta;
    }

    function updateFundingIndex(uint256 _marketId) public {
        int256 fundingIndex = getFundingIndex(_marketId);
        latestFundingIndex[_marketId] = fundingIndex;
        latestFundingTimestamp[_marketId] = block.timestamp;
    }

    function getPriceBufferRate(
        uint256 _marketId
    ) public view returns (int256) {
        int256 priceBuffer = priceManager.getPriceBuffer(_marketId);
        return
            (market.getMarketInfo(_marketId).fundingRateMultiplier *
                priceBuffer) / PRICE_BUFFER_PRECISION.toInt256();
    }

    function getFundingRate(uint256 _marketId) public view returns (int256) {
        int256 priceBufferRate = getPriceBufferRate(_marketId);
        return
            priceBufferRate +
            MathUtils._clamp(
                interestRate - priceBufferRate,
                -fundingRateDamper,
                fundingRateDamper
            );
    }

    function getFundingFeeToPay(
        OpenPosition calldata _position
    ) public view returns (int256) {
        uint256 marketId = _position.marketId;
        uint256 markPrice = priceManager.getMarkPrice(marketId);

        int256 sizeInUsd = orderUtils
            ._tokenToUsd(
                _position.size,
                markPrice,
                tokenInfo.getTokenDecimals(
                    market.getMarketInfo(marketId).baseAssetId
                )
            )
            .toInt256();
        int256 fundingFeeToPay = ((getFundingIndex(marketId) -
            _position.avgEntryFundingIndex) * sizeInUsd) /
            FUNDING_RATE_PRECISION;
        return fundingFeeToPay;
    }
}
