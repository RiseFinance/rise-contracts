// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IL3Gateway {
    function increaseTraderBalance(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) external;

    function addLiquidity(
        uint256 _marketId,
        bool _isLongReserve,
        uint256 _amount
    ) external;

    function withdrawAssetToL2(
        address _trader,
        uint256 _assetId,
        uint256 _amount
    ) external;

    function removeLiquidityToL2(
        uint256 _marketId,
        bool _isLongReserve,
        address _recipient,
        uint256 _amount
    ) external;
}
