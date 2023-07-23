import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
/**
 * struct OrderContext {
    bool _isLong;
    bool _isIncrease;
    uint256 _indexAssetId;
    uint256 _collateralAssetId;
    uint256 _sizeAbsInUsd;
    uint256 _collateralAbsInUsd;
    uint256 _limitPrice; // empty for market orders
}

* struct OrderRequest {
    address trader;
    bool isLong;
    bool isIncrease;
    uint256 indexAssetId; // redundant?
    uint256 collateralAssetId;
    uint256 sizeAbsInUsd;
    uint256 collateralAbsInUsd;
    uint256 limitPrice;
}
*/

function USD(amount: number) {
  return ethers.utils.parseUnits(amount.toString(), 20);
}

describe("Place Limit Order and Execute", function () {
  const USD_ID = 0;
  const ETH_ID = 1;

  const USD_DECIMALS = 20;
  const ETH_DECIMALS = 18;
  const PRICE_BUFFER_DECIMALS = 8;

  // Fixtures
  async function deployContracts() {
    const [deployer, trader, priceKeeper] = await ethers.getSigners();
    const l3Vault = await (await ethers.getContractFactory("L3Vault")).deploy();
    const orderBook = await (
      await ethers.getContractFactory("OrderBook")
    ).deploy(l3Vault.address);
    const priceManager = await (
      await ethers.getContractFactory("PriceManager")
    ).deploy(orderBook.address, priceKeeper.address);
    const orderRouter = await (
      await ethers.getContractFactory("OrderRouter")
    ).deploy(l3Vault.address, orderBook.address, priceManager.address);

    return {
      deployer,
      trader,
      priceKeeper,
      l3Vault,
      orderBook,
      priceManager,
      orderRouter,
    };
  }

  async function configureL3Vault(l3Vault: any) {
    await l3Vault.setAssetIdCounter(2); // ETH, USD
  }

  async function depositToTraderAccount(l3Vault: any, trader: any) {
    const depositAmount = ethers.utils.parseUnits("5000", USD_DECIMALS); // 5000 USD
    await l3Vault
      .connect(trader)
      .increaseTraderBalance(trader.address, USD_ID, depositAmount);
  }

  async function checkTraderAccountBalance() {}

  async function fillBuyOrderBookForTest(orderBook: any) {
    const bidPrices = [1945, 1946, 1947, 1948, 1949];

    for (let price of bidPrices) {
      //   console.log(">> filling orderbook with price: ", price);
      // place 10 orders per price tick
      for (let i = 0; i < 10; i++) {
        const orderContext = {
          _isLong: true,
          _isIncrease: true,
          _indexAssetId: ETH_ID,
          _collateralAssetId: USD_ID,
          _sizeAbsInUsd: ethers.utils.parseUnits("450", USD_DECIMALS), // x10 leverage
          _collateralAbsInUsd: ethers.utils.parseUnits("150", USD_DECIMALS),
          _limitPrice: USD(price),
        };
        await orderBook.placeLimitOrder(orderContext);
      }
    }
  }

  async function checkOrderSizeInUsdForPriceTick(orderBook: any) {
    const prices = [1945, 1946, 1947, 1948, 1949];
    for (let price of prices) {
      const size = await orderBook.orderSizeInUsdForPriceTick(
        ETH_ID,
        USD(price)
      );
      console.log(
        `>>> orderbook filled | price: ${price} | size: ${ethers.utils.formatUnits(
          size,
          USD_DECIMALS
        )} USD`
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
    const { deployer, trader, l3Vault, orderBook, priceManager, orderRouter } =
      await loadFixture(deployContracts);
    await configureL3Vault(l3Vault);
    await depositToTraderAccount(l3Vault, trader);

    // FIXME: just temporary
    await orderBook.initializeIndices(USD(1950));

    const orderContext = {
      _isLong: true,
      _isIncrease: true,
      _indexAssetId: ETH_ID,
      _collateralAssetId: USD_ID,
      _sizeAbsInUsd: USD(16000),
      _collateralAbsInUsd: USD(2000), // x8 leverage
      _limitPrice: USD(1950),
    };

    await orderRouter.connect(trader).placeLimitOrder(orderContext);

    const isBuy = true;
    const orderRequest = await orderBook.getOrderRequest(
      isBuy,
      ETH_ID,
      USD(1950),
      1
    ); // how to get order index?

    // 존재하는지부터 확인 필요
    expect(orderRequest.trader).to.equal(trader.address);
    expect(orderRequest.isLong).to.equal(true);
    expect(orderRequest.isIncrease).to.equal(true);
    expect(orderRequest.indexAssetId).to.equal(ETH_ID);
    expect(orderRequest.collateralAssetId).to.equal(USD_ID);
    expect(orderRequest.sizeAbsInUsd).to.equal(USD(16000));
    expect(orderRequest.collateralAbsInUsd).to.equal(USD(2000));
    expect(orderRequest.limitPrice).to.equal(USD(1950));
  });

  it("Should execute limit orders and apply price impact", async function () {
    const {
      deployer,
      trader,
      priceKeeper,
      l3Vault,
      orderBook,
      priceManager,
      orderRouter,
    } = await loadFixture(deployContracts);

    // initial setPrice
    await priceManager
      .connect(priceKeeper)
      .setPrice([ETH_ID], [USD(1950)], true);
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
    await orderBook.setPriceTickSize(ETH_ID, USD(1));

    // fill orderbook
    await configureL3Vault(l3Vault);
    await depositToTraderAccount(l3Vault, trader);
    await fillBuyOrderBookForTest(orderBook);

    await checkOrderSizeInUsdForPriceTick(orderBook);

    // FIXME: just temporary
    await orderBook.setMaxBidPrice(ETH_ID, USD(1949));
    await orderBook.setMinAskPrice(ETH_ID, USD(1950));

    // secondary setPrice (execute filled limit orders)
    console.log(
      "\n\n-------------------- setPrice & execute limit orders --------------------\n\n"
    );
    await priceManager
      .connect(priceKeeper)
      .setPrice([ETH_ID], [USD(1947)], false);

    const secondaryMarkPrice = await priceManager.getMarkPrice(ETH_ID);
    console.log(
      ">>> secondaryMarkPrice: ",
      ethers.utils.formatUnits(secondaryMarkPrice, USD_DECIMALS)
    );
  });
});
