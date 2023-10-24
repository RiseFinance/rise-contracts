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
import "../order/PriceFetcher.sol";

import "hardhat/console.sol";

contract OrderExecutor is PnlManager {
    PositionHistory public positionHistory;
    PositionVault public positionVault;
    PositionFee public positionFee;
    PriceFetcher public priceFetcher;

    struct ExecutionContext {
        OpenPosition openPosition;
        OrderExecType execType;
        bytes32 key;
        uint256 marketId;
        uint256 marginAssetId;
        uint256 sizeAbs;
        uint256 marginAbs;
        uint256 positionRecordId;
        uint256 avgExecPrice;
        int256 pnl;
    }

    constructor(
        address _traderVault,
        address _risePool,
        address _funding,
        address _market,
        address _positionHistory,
        address _positionVault,
        address _positionFee,
        address _priceFetcher
    ) PnlManager(_traderVault, _risePool, _funding, _market) {
        positionHistory = PositionHistory(_positionHistory);
        positionVault = PositionVault(_positionVault);
        positionFee = PositionFee(_positionFee);
        priceFetcher = PriceFetcher(_priceFetcher);
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


        //TODO : reserve 없는 pair에 대한 처리

        req.isLong
            ? risePool.increaseLongReserveAmount(ec.marketId, ec.sizeAbs)
            : risePool.increaseShortReserveAmount(ec.marketId, ec.sizeAbs);

        if (ec.execType == OrderExecType.OpenPosition) {
            /// @dev for OpenPosition: PositionRecord => OpenPosition

            ec.positionRecordId = positionHistory.openPositionRecord(
                OpenPositionRecordParams(
                    tx.origin,
                    req.marketId,
                    ec.sizeAbs,
                    ec.avgExecPrice
                )
            );

            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    ec.execType,
                    ec.key,
                    true, // isOpening
                    tx.origin,
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
                    tx.origin,
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
                    tx.origin,
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
            ec.marginAbs // changing Leverage
        );

        ec.positionRecordId = ec.openPosition.currentPositionRecordId;

        if (ec.execType == OrderExecType.DecreasePosition) {
            positionVault.updateOpenPosition(
                UpdatePositionParams(
                    ec.execType,
                    ec.key,
                    false, // isOpening
                    tx.origin,
                    req.isLong,
                    ec.positionRecordId,
                    req.marketId,
                    ec.avgExecPrice,
                    ec.sizeAbs,
                    ec.marginAbs,
                    req.isIncrease, // isIncreaseInSize
                    req.isIncrease // isIncreaseInMargin // FIXME: not correct now
                )
            );

            positionHistory.updatePositionRecord(
                UpdatePositionRecordParams(
                    tx.origin,
                    ec.key,
                    ec.openPosition.currentPositionRecordId,
                    req.isIncrease,
                    ec.pnl,
                    ec.sizeAbs,
                    ec.avgExecPrice
                )
            );
        } else if (ec.execType == OrderExecType.ClosePosition) {
            // TODO: pay out margin if not requested as order request param

            positionVault.deleteOpenPosition(ec.key);

            positionHistory.closePositionRecord(
                ClosePositionRecordParams(
                    tx.origin,
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
    function ExecuteCloseOrder( OpenPosition memory position ) public {
        OrderRequest memory req;
        ExecutionContext memory ec;
        ec.openPosition = position;
        ec.execType = OrderExecType.ClosePosition;
        ec.key = keccak256(
            abi.encodePacked(
                position.trader,
                position.isLong,
                position.marketId
            )
        );
        ec.marketId = position.marketId;
        ec.marginAssetId = market.getMarketInfo(ec.marketId).marginAssetId;
        ec.sizeAbs = position.size;
        ec.marginAbs = position.margin;
        ec.positionRecordId = position.currentPositionRecordId;
        /*
        ec.avgExecPrice = priceFetcher._getAvgExecPrice(
            ec.marketId,
            ec.sizeAbs,
            !position.isLong   // opposite action of calldata position
        );
        */
        ec.avgExecPrice = priceFetcher._getAvgExecPrice(
            ec.marketId,
            ec.sizeAbs,
            !position.isLong,
            true,
            position.liquidationPrice   // opposite action of calldata position
        ); // liquidation executed at exact price just like limit order 
        req.isLong = !position.isLong;
        req.isIncrease = false;
        req.orderType = OrderType.Market;
        req.marketId = ec.marketId;
        req.sizeAbs = ec.sizeAbs;
        req.marginAbs = ec.marginAbs;
        req.limitPrice = 0;
        _executeDecreasePosition(req, ec);
        

    }
}//Hard to open, hard to close?
// liquidation만 갑자기 사라지면 어떡하냐 
