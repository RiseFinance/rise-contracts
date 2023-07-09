// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IL3Vault {
    struct Position {
        bool hasProfit;
        uint256 size;
        uint256 collateralSize;
        uint256 avgOpenPrice;
        uint256 avgClosePrice;
        uint256 lastUpdatedTime;
        uint256 realizedPnlInUsd;
        uint256 realizedPnlInIndexTokenCount;
    }

    function addLiquidity(uint256 assetId, uint256 amount) external payable;

    function removeLiquidity(uint256 assetId, uint256 amount) external;

    function depositEth() external payable;

    function withdrawEth(uint256 amount) external;

    function openPosition(
        address _account,
        uint256 _collateralAssetId,
        uint256 _indexAssetId,
        uint256 _size,
        uint256 _collateralSize,
        bool _isLong,
        bool _isMarketOrder
    ) external returns (bytes32);

    function closePosition(
        address _account,
        uint256 _collateralAssetId,
        uint256 _indexAssetId,
        bool _isLong,
        bool _isMarketOrder
    ) external returns (bool);

    function getPosition(bytes32 _key) external view returns (Position memory);
}
