import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployContract } from "../utils/deployer";

const USD_ID = 0;
const ETH_ID = 1;
const ETH_USD = 1;

const USD_DECIMALS = 20;
const ETH_DECIMALS = 18;
const PRICE_BUFFER_DECIMALS = 8;
function USD(amount: number) {
  return ethers.utils.parseUnits(amount.toString(), USD_DECIMALS);
}
function ETH(amount: number) {
  return ethers.utils.parseUnits(amount.toString(), ETH_DECIMALS);
}

describe.only("Place Limit Order and Execute", function () {

  // Fixtures
  async function deployContracts() {
    const [deployer, trader, priceKeeper,limitOrderTrader] = await ethers.getSigners();

  const mathUtils = await deployContract("MathUtils");

    // TraderVault
    const traderVault = await deployContract("TraderVault");
    
    const positionFee = await deployContract("PositionFee", [traderVault.address]);
    // Market
    const market = await deployContract("Market");
  
    // TokenInfo
    const tokenInfo = await deployContract("TokenInfo", [market.address]);
  
    // RisePool
    const risePool = await deployContract("RisePool");
  
    // GlobalState
    const globalState = await deployContract("GlobalState", [], mathUtils.address);
  
    // PriceManager
    const priceManager = await deployContract("PriceManager", [
      globalState.address,
      tokenInfo.address,
    ]);
  
        // Funding
        const funding = await deployContract(
          "Funding",
          [
            priceManager.address,
            globalState.address,
            tokenInfo.address,
            market.address,
          ],
          mathUtils.address
        );
  
    // PositionVault
    const positionVault = await deployContract(
      "PositionVault",
      [funding.address],
      mathUtils.address
    );
  
    // OrderValidator
    const orderValidator = await deployContract("OrderValidator", [
      positionVault.address,
      globalState.address,
      risePool.address,
    ]);
  
    // OrderHistory
    const orderHistory = await deployContract("OrderHistory", [
      traderVault.address,
    ]);
  
    // PositionHistory
    const positionHistory = await deployContract(
      "PositionHistory",
      [positionVault.address, traderVault.address],
      mathUtils.address
    );
  
    // MarketOrder
    const marketOrder = await deployContract("MarketOrder", [
      traderVault.address,
      risePool.address,
      market.address,
      positionHistory.address,
      positionVault.address,
      orderValidator.address,
      orderHistory.address,
      globalState.address,
    ]);
  
    // OrderBook
    const orderBook = await deployContract(
      "OrderBook",
      [
        traderVault.address,
        risePool.address,
        market.address,
        positionHistory.address,
        positionVault.address,
      ],
      mathUtils.address
    );



    // OrderRouter
    const orderRouter = await deployContract("OrderRouter", [
      marketOrder.address,
      orderBook.address,
    ]);

    // PriceRouter
    const priceRouter = await deployContract("PriceRouter", [
      priceManager.address,
      orderBook.address,
      priceKeeper.address,
    ]);

    const listingManager = await deployContract("ListingManager");

    return {
      deployer,
      trader,
      priceKeeper,
      priceRouter,
      traderVault,
      orderBook,
      priceManager,
      orderRouter,
      listingManager,
      limitOrderTrader,
      market
    };
  }

  // async function configureL3Vault(l3Vault: any) {
  //   await l3Vault.setAssetIdCounter(2); // ETH, USD
  // }

  async function depositToTraderAccount(traderVault: any, trader: any) {
    const depositAmount = ethers.utils.parseUnits("5000", USD_DECIMALS); // 5000 USD
    await traderVault
      .connect(trader)
      .increaseTraderBalance(trader.address, USD_ID, depositAmount);
  }

  async function fillBuyOrderBookForTest(orderBook: any, limitOrderTrader: any) {
    const bidPrices = [1945, 1946, 1947, 1948, 1949];

    for (let price of bidPrices) {
      //   console.log(">> filling orderbook with price: ", price);
      // place 10 orders per price tick
      for (let i = 0; i < 10; i++) {
        const orderParams = {
        trader : limitOrderTrader.address,
        isLong: true,
        isIncrease: true,
        orderType: 1,
        marketId: ETH_USD,
        sizeAbs: ETH(1),
        marginAbs: USD(150),
        limitPrice: USD(price),
        };
        await orderBook.placeLimitOrder(orderParams);
      }
    }
  }

  async function checkOrderSizeForPriceTick(orderBook: any) {
    const prices = [1945, 1946, 1947, 1948, 1949];
    for (let price of prices) {
      const size = await orderBook.orderSizeForPriceTick(
        ETH_USD,
        USD(price)
      );
      console.log(
        `>>> orderbook filled | price: ${price} | size: ${ethers.utils.formatUnits(
          size,
          ETH_DECIMALS
        )} ETH`
      );
    }
  }

  async function fillSellOrderBookForTest(orderBook: any) {
    const askPrices = [1950, 1951, 1952, 1953, 1954];
  }

  async function printOrderBook(orderBook: any) {
    const maxPrice = 1949;
    const minPrice = 1945;

    // 각 가격대의 첫 번째 주문만 출력
    for (let i = minPrice; i <= maxPrice; i++) {
      const orderRequest = await orderBook.getOrderRequest(true, ETH_ID, i, 1);
      console.log(
        `${i} USD/ETH | size: ${ethers.utils.formatUnits(
          orderRequest.sizeAbsInUsd,
          USD_DECIMALS
        )} USD | trader: ${orderRequest.trader}`
      );
    }
  }

  // this.beforeEach(async () => {});
  // this.afterEach(async () => {});

  // TODO: configure different orderbook states

  it("Should place a limit order (ETH/USD x8 Long Increase)", async function () {
    const { deployer, trader, traderVault, orderBook, priceManager, orderRouter, listingManager } =
      await loadFixture(deployContracts);
    // await configureL3Vault(l3Vault);
    await depositToTraderAccount(traderVault, trader);

    let m = {
      marketId : ETH_USD,
      priceTickSize : 10**8,
      baseAssetId : ETH_ID,
      quoteAssetId : USD_ID,
      longReserveAssetId: ETH_ID,
      shortReserveAssetId: USD_ID,
      marginAssetId : USD_ID,
      fundingRateMultiplier : 0,
      marketMakerToken : trader.address,
    }
    await listingManager.createRisePerpsMarket(m)
    const orderRequest = {
      trader : trader.address,
      isLong: true,
      isIncrease: true,
      orderType: 1,
      marketId: ETH_USD,
      sizeAbs: ETH(80),
      marginAbs: USD(2000), // x8 leverage
      limitPrice: USD(1950),
    };

    await orderRouter.connect(trader).placeLimitOrder(orderRequest);

    const isBuy = true;
    const orderRequestResult = await orderBook.getOrderRequest(
      isBuy,
      ETH_ID,
      USD(1950),
      1
    ); // how to get order index?

    // 존재하는지부터 확인 필요
    expect(orderRequestResult.trader).to.equal(trader.address);
    expect(orderRequestResult.isLong).to.equal(true);
    expect(orderRequestResult.isIncrease).to.equal(true);
    expect(orderRequestResult.marketId).to.equal(ETH_USD);
    expect(orderRequestResult.sizeAbs).to.equal(ETH(80));
    expect(orderRequestResult.marginAbs).to.equal(USD(2000));
    expect(orderRequestResult.limitPrice).to.equal(USD(1950));
  });

  it("Should execute limit orders and apply price impact", async function () {
    const {
      deployer,
      trader,
      priceKeeper,
      traderVault,
      orderBook,
      market,
      priceRouter,
      priceManager,
      limitOrderTrader,
      orderRouter,
    } = await loadFixture(deployContracts);

    // initial setPrice
    await priceRouter
      .connect(priceKeeper)
      .setPricesAndExecuteLimitOrders([ETH_USD], [USD(1950)], true);
    const initialMarkPrice = await priceManager.getMarkPrice(ETH_ID);
    console.log(
      ">>> initialMarkPrice: ",
      ethers.utils.formatUnits(initialMarkPrice, USD_DECIMALS)
    );

    // FIXME: just temporary => no need (automatically initialized to 0)
    // await orderBook.initializeIndices(USD(1945));
    // await orderBook.initializeIndices(USD(1946));
    // await orderBook.initializeIndices(USD(1947));
    // await orderBook.initializeIndices(USD(1948));
    // await orderBook.initializeIndices(USD(1949));

    // FIXME: just temporary
    await market.setPriceTickSize(ETH_USD, USD(1));

    // fill orderbook
    // await configureL3Vault(l3Vault);
    await depositToTraderAccount(traderVault, trader);
    await fillBuyOrderBookForTest(orderBook,limitOrderTrader);

    await checkOrderSizeForPriceTick(orderBook);

    // FIXME: just temporary
    // await orderBook.setMaxBidPrice(ETH_ID, USD(1949));
    // await orderBook.setMinAskPrice(ETH_ID, USD(1950));

    // secondary setPrice (execute filled limit orders)
    console.log(
      "\n\n-------------------- setPrice & execute limit orders --------------------\n\n"
    );
    await priceRouter
      .connect(priceKeeper)
      .setPricesAndExecuteLimitOrders([ETH_USD], [USD(1947)], false);

    const secondaryMarkPrice = await priceManager.getMarkPrice(ETH_USD);
    console.log(
      ">>> secondaryMarkPrice: ",
      ethers.utils.formatUnits(secondaryMarkPrice, USD_DECIMALS)
    );
  });
});
