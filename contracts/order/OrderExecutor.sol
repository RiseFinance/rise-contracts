// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../common/constants.sol";
import "../common/structs.sol";
import "../common/params.sol";
import "../position/PositionHistory.sol";
import "../position/PositionVault.sol";
import "../position/PnlManager.sol";
import "../account/TraderVault.sol";
import "../risepool/RisePool.sol";
import "../fee/PositionFee.sol";

contract OrderExecutor is PnlManager {
    PositionHistory public positionHistory;
    PositionVault public positionVault;
    PositionFee public positionFee;

    struct ExecutionContext {
        OpenPosition openPosition;
        OrderExecType execType;
        bytes32 key;
        uint256 marginAssetId;
        uint256 sizeAbs;
        uint256 marginAbs;
        uint256 positionRecordId;
        uint256 avgExecPrice;
        int256 pnl;
    }

    function _executeIncreasePosition(
        OrderRequest memory req,
        ExecutionContext memory ec
    ) internal {
        positionFee.payPositionFee(
            tx.origin,
            ec.sizeAbs,
            ec.avgExecPrice,
            ec.marginAssetId,
            req.orderType
        );
        traderVault.decreaseTraderBalance(
            tx.origin,
            ec.marginAssetId,
            ec.marginAbs
        );

        req.isLong
            ? risePool.increaseLongReserveAmount(ec.marginAssetId, ec.sizeAbs)
            : risePool.increaseShortReserveAmount(ec.marginAssetId, ec.sizeAbs);

        if (ec.execType == OrderExecType.OpenPosition) {
            /// @dev for OpenPosition: PositionRecord => OpenPosition

            ec.positionRecordId = positionHistory.openPositionRecord(
                OpenPositionRecordParams(
                    msg.sender,
                    req.marketId,
                    ec.sizeAbs,
                    ec.avgExecPrice,
                    0
                )
            );

            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    ec.execType,
                    ec.key,
                    true, // isOpening
                    msg.sender,
                    req.isLong,
                    ec.positionRecordId,
                    req.marketId,
                    ec.avgExecPrice,
                    ec.sizeAbs,
                    ec.marginAbs,
                    req.isIncrease, // isIncreaseInSize
                    req.isIncrease // isIncreaseInMargin
                )
            );
        } else if (ec.execType == OrderExecType.IncreasePosition) {
            /// @dev for IncreasePosition: OpenPosition => PositionRecord

            ec.positionRecordId = ec.openPosition.currentPositionRecordId;

            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    ec.execType,
                    ec.key,
                    false, // isOpening
                    msg.sender,
                    req.isLong,
                    ec.positionRecordId,
                    req.marketId,
                    ec.avgExecPrice,
                    ec.sizeAbs,
                    ec.marginAbs,
                    req.isIncrease, // isIncreaseInSize
                    req.isIncrease // isIncreaseInMargin
                )
            );

            positionHistory.updatePositionRecord(
                UpdatePositionRecordParams(
                    msg.sender,
                    ec.key,
                    ec.positionRecordId,
                    req.isIncrease,
                    ec.pnl,
                    ec.sizeAbs,
                    ec.avgExecPrice
                )
            );
        } else {
            revert("Invalid execution type");
        }
    }

    function _executeDecreasePosition(
        OrderRequest memory req,
        ExecutionContext memory ec
    ) internal {
        positionFee.payPositionFee(
            tx.origin,
            ec.sizeAbs,
            ec.avgExecPrice,
            ec.marginAssetId,
            req.orderType
        );
        // PnL settlement
        ec.pnl = settlePnL(
            ec.openPosition,
            req.isLong,
            ec.avgExecPrice,
            req.marketId,
            ec.sizeAbs,
            ec.marginAbs
        );
        ec.positionRecordId = ec.openPosition.currentPositionRecordId;

        if (ec.execType == OrderExecType.DecreasePosition) {
            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    ec.execType,
                    ec.key,
                    false, // isOpening
                    msg.sender,
                    req.isLong,
                    ec.positionRecordId,
                    req.marketId,
                    ec.avgExecPrice,
                    ec.sizeAbs,
                    req.marginAbs,
                    req.isIncrease, // isIncreaseInSize
                    req.isIncrease // isIncreaseInMargin
                )
            );

            positionHistory.updatePositionRecord(
                UpdatePositionRecordParams(
                    msg.sender,
                    ec.key,
                    ec.openPosition.currentPositionRecordId,
                    req.isIncrease,
                    ec.pnl,
                    ec.sizeAbs,
                    ec.avgExecPrice
                )
            );
        } else if (ec.execType == OrderExecType.ClosePosition) {
            positionVault.deleteOpenPosition(ec.key);

            positionHistory.closePositionRecord(
                ClosePositionRecordParams(
                    msg.sender,
                    ec.openPosition.currentPositionRecordId,
                    ec.pnl,
                    ec.sizeAbs,
                    ec.avgExecPrice
                )
            );
        } else {
            revert("Invalid execution type");
        }
    }
}
