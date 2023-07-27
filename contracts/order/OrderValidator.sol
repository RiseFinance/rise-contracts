// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/Context.sol";
import "../risepool/RisePool.sol";
import "../market/TokenInfo.sol";
import "../position/PositionVault.sol";
import "../global/GlobalState.sol";

contract OrderValidator is Context {
    RisePool public risePool;
    TokenInfo public tokenInfo;
    PositionVault public positionVault;
    GlobalState public globalState;

    function validateIncreaseExecution(OrderContext calldata c) external view {
        uint256 tokenPoolAmount = risePool.tokenPoolAmounts(c._indexAssetId);
        uint256 tokenReserveAmount = risePool.tokenReserveAmounts(
            c._indexAssetId
        );
        uint256 maxLongCapacity = positionVault.maxLongCapacity(
            c._indexAssetId
        );
        uint256 maxShortCapacity = positionVault.maxShortCapacity(
            c._indexAssetId
        );

        require(
            tokenPoolAmount >= tokenReserveAmount + c._sizeAbsInUsd,
            "L3Vault: Not enough token pool amount"
        );

        uint256 totalSizeInUsd = globalState
            .getGlobalPositionState(c._isLong, c._indexAssetId)
            .totalSizeInUsd;

        if (c._isLong) {
            require(
                maxLongCapacity >= totalSizeInUsd + c._sizeAbsInUsd,
                "L3Vault: Exceeds max long capacity"
            );
        } else {
            require(
                maxShortCapacity >= totalSizeInUsd + c._sizeAbsInUsd,
                "L3Vault: Exceeds max short capacity"
            );
        }
    }

    function validateDecreaseExecution(
        OrderContext calldata c,
        bytes32 _key,
        uint256 _markPrice
    ) external view {
        Position memory position = positionVault.getPosition(_key);

        require(
            position.sizeInUsd >= c._sizeAbsInUsd,
            "L3Vault: Not enough position size"
        );
        require(
            position.collateralInUsd >=
                _tokenToUsd(
                    c._collateralAbsInUsd,
                    _markPrice,
                    tokenInfo.tokenDecimals(c._collateralAssetId)
                ),
            "L3Vault: Not enough collateral size"
        );
    }
}
