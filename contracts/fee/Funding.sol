// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../common/structs.sol";

import "../oracle/PriceManager.sol";
import "../global/GlobalState.sol";
import "../order/OrderUtils.sol";
import "../market/TokenInfo.sol";
import "../market/Market.sol";

contract Funding {
    using SafeCast for int256;
    using SafeCast for uint256;

    PriceManager public priceManager;
    GlobalState public globalState;
    OrderUtils public orderUtils;
    TokenInfo public tokenInfo;
    Market public market;

    // int256 public constant FUNDING_FEE_CONSTANT = 1;
    int256 public constant FUNDING_FEE_PRECISION = 1e26;
    // TODO: FUNDING_FEE_CONSTANT, FUNDING_FEE_PRECISION 값 확인 필요
    mapping(uint256 => int256) latestFundingIndex; // assetId => fundingIndex
    mapping(uint256 => uint256) latestFundingTimestamp; // assetId => timestamp

    constructor(
        address _priceManager,
        address _globalState,
        address _orderUtils,
        address _tokenInfo,
        address _market
    ) {
        priceManager = PriceManager(_priceManager);
        globalState = GlobalState(_globalState);
        orderUtils = OrderUtils(_orderUtils);
        tokenInfo = TokenInfo(_tokenInfo);
        market = Market(_market);
    }

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

    function getFundingRate(uint256 _marketId) public view returns (int256) {
        int256 priceBuffer = priceManager.getPriceBuffer(_marketId);
        return
            market.getMarketInfo(_marketId).fundingFeeMultiplier * priceBuffer;
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
            _position.entryFundingIndex) * sizeInUsd) / FUNDING_FEE_PRECISION;
        // TODO: position에 entryFundingIndex 추가
        return fundingFeeToPay;
    }
}
