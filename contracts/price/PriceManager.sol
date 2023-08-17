// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../common/constants.sol";

import "../market/TokenInfo.sol";
import "../global/GlobalState.sol";

import "hardhat/console.sol";

contract PriceManager {
    using SafeCast for int256;
    using SafeCast for uint256;

    GlobalState public globalState;
    TokenInfo public tokenInfo;

    mapping(uint256 => uint256) public indexPrices;
    mapping(uint256 => uint256) public priceBufferUpdatedTime;
    mapping(uint256 => int256) public lastPriceBuffer;

    event Execution(uint256 marketId, int256 price);

    constructor(address _globalState, address _tokenInfo) {
        globalState = GlobalState(_globalState);
        tokenInfo = TokenInfo(_tokenInfo);
    }

    function setPrice(
        uint256 _marketId,
        uint256 _price // new index price from the data source
    ) external {
        require(_price > 0, "PriceManager: price has to be positive");

        indexPrices[_marketId] = _price;
    }

    function getPriceBuffer(uint256 _marketId) public view returns (int256) {
        return
            tokenInfo
                .getBaseTokenSizeToPriceBufferDeltaMultiplier(_marketId)
                .toInt256() * (globalState.getLongShortOIDiff(_marketId));
    }

    function getIndexPrice(uint256 _marketId) public view returns (uint256) {
        return indexPrices[_marketId];
    }

    function getMarkPrice(uint256 _marketId) public view returns (uint256) {
        int256 newPriceBuffer = getPriceBuffer(_marketId);
        console.log("******* newPriceBuffer:", newPriceBuffer.toUint256());
        int256 newPriceBufferInUsd = ((indexPrices[_marketId]).toInt256() *
            newPriceBuffer) / (PRICE_BUFFER_PRECISION).toInt256();
        console.log(
            "******* newPriceBufferInUsd:",
            newPriceBufferInUsd.toUint256()
        );
        return
            ((indexPrices[_marketId]).toInt256() + newPriceBufferInUsd)
                .toUint256();
    }

    function getAvgExecPrice(
        uint256 _marketId,
        uint256 _size,
        bool _isBuy
    ) public view returns (uint256) {
        uint256 _indexPrice = getIndexPrice(_marketId);
        // require first bit of _size is 0
        uint256 tokenDecimals = tokenInfo.getBaseTokenDecimals(_marketId);
        uint256 sizeInUsd = (_size * getIndexPrice(_marketId)) /
            10 ** tokenDecimals;

        require(_indexPrice > 0, "PriceManager: price not set");
        int256 intSize = _isBuy
            ? (sizeInUsd).toInt256()
            : -(sizeInUsd).toInt256();
        int256 priceBufferChange = (intSize *
            (tokenInfo.getBaseTokenSizeToPriceBufferDeltaMultiplier(_marketId))
                .toInt256()) / (SIZE_TO_PRICE_BUFFER_PRECISION).toInt256();
        int256 averagePriceBuffer = (getPriceBuffer(_marketId) +
            priceBufferChange) / 2;
        int256 averageExecutedPrice = (_indexPrice).toInt256() +
            ((_indexPrice).toInt256() * averagePriceBuffer) /
            (PRICE_BUFFER_PRECISION).toInt256();
        // emit Execution(_marketId, averageExecutedPrice);

        return (averageExecutedPrice).toUint256();
    }
}
