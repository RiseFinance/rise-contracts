// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../common/constants.sol";

import "../market/TokenInfo.sol";
import "../global/GlobalState.sol";

contract PriceManager {
    using SafeCast for int256;
    using SafeCast for uint256;

    GlobalState public globalState;
    TokenInfo public tokenInfo;

    mapping(uint256 => uint256) public indexPrices;
    mapping(uint256 => int256) public lastPriceBuffer;

    // mapping(uint256 => uint256) public priceBufferUpdatedTimes;

    constructor(address _globalState, address _tokenInfo) {
        globalState = GlobalState(_globalState);
        tokenInfo = TokenInfo(_tokenInfo);
    }

    // TODO: onlyPriceKeeper
    function setPrice(
        uint256 _marketId,
        uint256 _price // new index price from the data source
    ) external {
        require(_price > 0, "PriceManager: price has to be positive");

        indexPrices[_marketId] = _price;
    }

    function getIndexPrice(uint256 _marketId) public view returns (uint256) {
        return indexPrices[_marketId];
    }

    function getPriceBuffer(uint256 _marketId) public view returns (int256) {
        return
            _calculatePriceBuffer(
                _marketId,
                globalState.getLongShortOIDiff(_marketId)
            );
    }

    // TODO: check - 현재 구현으로는 이번 주문에 의해 변경되는 Long/Short OI는 반영되지 않음
    // 아래 getAvgExecPrice에서 구현함 (이번 주문에 의한 변화: priceBufferChange)

    // Mark Price used for calculation of unrealized PnL, liquidation conditions
    // funding fee and limit order execution prices
    function getMarkPrice(uint256 _marketId) public view returns (uint256) {
        int256 newPriceBuffer = getPriceBuffer(_marketId);

        int256 newPriceBufferSizeInUsd = ((indexPrices[_marketId]).toInt256() *
            newPriceBuffer) / PRICE_BUFFER_PRECISION.toInt256();

        return
            ((indexPrices[_marketId]).toInt256() + newPriceBufferSizeInUsd)
                .toUint256();
    }

    function getAvgExecPrice(
        uint256 _marketId,
        uint256 _size,
        bool _isBuy
    ) public view returns (uint256) {
        uint256 _indexPrice = getIndexPrice(_marketId);
        require(_indexPrice > 0, "PriceManager: price not set");

        // size as OpenInterestDiff change
        int256 openInterestDelta = _isBuy
            ? (_size).toInt256()
            : -(_size).toInt256();

        int256 priceBufferChange = _calculatePriceBuffer(
            _marketId,
            openInterestDelta
        );

        int256 avgPriceBuffer = (getPriceBuffer(_marketId) +
            priceBufferChange) / 2;

        int256 avgExecPrice = (_indexPrice).toInt256() +
            ((_indexPrice).toInt256() * avgPriceBuffer) /
            (PRICE_BUFFER_PRECISION).toInt256();

        require(avgExecPrice > 0, "PriceManager: avgExecPrice <= 0");

        return (avgExecPrice).toUint256();
    }

    function _calculatePriceBuffer(
        uint256 _marketId,
        int256 _openInterestDifference
    ) internal view returns (int256) {
        return
            (((
                tokenInfo.getBaseTokenSizeToPriceBufferDeltaMultiplier(
                    _marketId
                )
            ).toInt256() * _openInterestDifference) *
                PRICE_BUFFER_PRECISION.toInt256()) /
            (TOKEN_SIZE_PRECISION.toInt256() *
                PRICE_BUFFER_DELTA_MULTIPLIER_PRECISION.toInt256());
    }
}
