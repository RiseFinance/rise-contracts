// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {USD_PRECISION} from "../common/constants.sol";

contract OrderUtils {
    function _usdToToken(
        uint256 _usdAmount,
        uint256 _tokenPrice,
        uint256 _tokenDecimals
    ) public pure returns (uint256) {
        return
            ((_usdAmount * 10 ** _tokenDecimals) / USD_PRECISION) / _tokenPrice;
    }

    function _tokenToUsd(
        uint256 _tokenAmount,
        uint256 _tokenPrice,
        uint256 _tokenDecimals
    ) public pure returns (uint256) {
        return
            ((_tokenAmount * _tokenPrice) * USD_PRECISION) /
            10 ** _tokenDecimals;
    }

    function _getPositionKey(
        address _account,
        bool _isLong,
        uint256 _marketId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _isLong, _marketId));
    }

    // TODO: delete
    // function _getAvgExecutionPrice(
    //     uint256 _basePrice,
    //     uint256 _priceImpactInUsd,
    //     bool _isIncrease
    // ) internal pure returns (uint256) {
    //     return
    //         _isIncrease
    //             ? _basePrice + (_priceImpactInUsd / 2)
    //             : _basePrice - (_priceImpactInUsd / 2);
    // }
}
