// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../common/Structs.sol";
import "../global/GlobalState.sol";
import "../order/OrderUtils.sol";
import "../oracle/PriceManager.sol";
import "../market/Market.sol";
import "../market/TokenInfo.sol";

contract FundingFee {
    GlobalState public globalState;
    PriceManager public priceManager;
    Market public market;
    TokenInfo public tokenInfo;
    OrderUtils public orderUtils;

    int256 FUNDING_FEE_CONSTANT = 1e18;
    int256 FUNDING_FEE_PRECISION = 1e18;
    // TODO: FUNDING_FEE_CONSTANT, FUNDING_FEE_PRECISION 값 확인 필요
    mapping(uint256 => int256) latestFundingIndex; // assetId => cumulativeFundingRate
    mapping(uint256 => uint256) latestFundingTimestamp; // assetId => timestamp

    function updateCumulativeFundingRate(uint256 _marketId) external {
        int256 fundingIndexDelta = getFundingRate(_marketId) *
            int256(block.timestamp - latestFundingTimestamp[_marketId]);
        latestFundingIndex[_marketId] =
            latestFundingIndex[_marketId] +
            fundingIndexDelta;
        latestFundingTimestamp[_marketId] = block.timestamp;
    }

    function getFundingRate(uint256 _marketId) public view returns (int256) {
        uint256 longOpenInterest = globalState.getOpenInterest(_marketId, true);
        uint256 shortOpenInterest = globalState.getOpenInterest(
            _marketId,
            false
        );
        // TODO: getOpenInterest 구현 필요
        require(
            longOpenInterest < 2 ** 255 && shortOpenInterest < 2 ** 255,
            "FundingFee: open interest overflow"
        );
        return
            (FUNDING_FEE_CONSTANT *
                (int256(longOpenInterest) - int256(shortOpenInterest))) /
            (int256(longOpenInterest) + int256(shortOpenInterest));
    }

    function getFundingFeeToPay(
        uint256 _marketId,
        Position calldata _position
    ) public view returns (int256) {
        uint256 markPrice = priceManager.getMarkPrice(_marketId);

        uint256 sizeInUsd = orderUtils._tokenToUsd(
            _position.size,
            markPrice,
            tokenInfo.tokenDecimals(market.getMarketInfo(_marketId).baseAssetId)
        );

        int256 fundingFeeToPay = (int256(sizeInUsd) *
            (latestFundingIndex[_marketId] - _position.entryFundingIndex)) /
            FUNDING_FEE_PRECISION;
        // TODO: position에 entryFundingIndex 추가
        return fundingFeeToPay;
    }
}
