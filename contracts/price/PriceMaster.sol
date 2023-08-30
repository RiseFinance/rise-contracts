// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "./PriceManager.sol";
import "../orderbook/OrderBook.sol";

contract PriceMaster {
    PriceManager public priceManager;
    OrderBook public orderBook;

    mapping(address => bool) public isPriceKeeper;

    modifier onlyPriceKeeper() {
        require(
            isPriceKeeper[msg.sender],
            "PriceManager: Should be called by keeper"
        );
        _;
    }

    constructor(
        address _priceManager,
        address _orderBook,
        address _keeperAddress
    ) {
        priceManager = PriceManager(_priceManager);
        orderBook = OrderBook(_orderBook);
        isPriceKeeper[_keeperAddress] = true;
    }

    function setPricesAndExecuteLimitOrders(
        uint256[] calldata _marketId,
        uint256[] calldata _price, // new index price from the data source
        bool _isInitialize
    ) public onlyPriceKeeper {
        require(_marketId.length == _price.length, "PriceMaster: Wrong input");
        uint256 l = _marketId.length;
        for (uint256 i = 0; i < l; i++) {
            //priceManager.setPrice(_marketId[i], _price[i]);  //setPrice == setIndexPrice
            //uint256 prev = priceManager.getMarkPrice(_marketId[i]);

            if (!_isInitialize) {
                bool isBuy = _price[i] <
                    priceManager.getIndexPrice(_marketId[i]);    
                    /// 이러면 price buffer가 위로 크게 생겨서 index는 감소했는데 mark는 증가하는 경우가 커버 안됨 
                    ///- always index price feed with limit execution ->market execution -> price feed
                    ///이렇게 가면 문제 없는데 market execution 하면서 끝나면 OI diff가 global state 수정되고
                    /// 그러면 그때 바로 limit order execution이 한번 있어야 됨
                    /// 바로 limit order execution이 없으면 다음번 price feed에서 price feed 사이에 있었던 누적 price buffer 고려해서 한번에 시행?
                    /// practically every market order followed by limit order execution is unrealistic
                    ///
                priceManager.setPrice(_marketId[i], _price[i]);    
                orderBook.executeLimitOrders( 
                    isBuy,
                    _marketId[i]
                ); //execute limit orders -> OI update 됨
            }

        }
    }
}
