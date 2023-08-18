import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { deployForTest } from "./test_deploy";
import {
  formatETH,
  formatUSDC,
  formatPosition,
  formatOrderRecord,
  formatPositionRecord,
  formatGlobalPositionState,
} from "../utils/formatter";

const USDC_ID = 0;
const ETH_ID = 1;
const ETH_USDC_MARKET_ID = 1;

const USDC_DECIMALS = 20;
const ETH_DECIMALS = 18;
const PRICE_BUFFER_DECIMALS = 10;
const PRICE_BUFFER_DELTA_MULTIPLIER_DECIMALS = 10;

// TODO:check if we need multiplier for USDC
const USDC_MULTIPLIER = ethers.utils.parseUnits(
  "1",
  PRICE_BUFFER_DELTA_MULTIPLIER_DECIMALS
);
const ETH_MULTIPLIER = ethers.utils.parseUnits(
  "0.0001",
  PRICE_BUFFER_DELTA_MULTIPLIER_DECIMALS
);
const ETH_USDC_MARKET_TICK_SIZE = 1e8;
const ETH_USDC_MARKET_FUNDING_RATE_MULTIPLIER = 0;

const DEPOSIT_AMOUNT = ethers.utils.parseUnits("500000", USDC_DECIMALS);

const LONG_LIQUIDITY_AMOUNT = ethers.utils.parseUnits("20000", ETH_DECIMALS);
const SHORT_LIQUIDITY_AMOUNT = ethers.utils.parseUnits(
  "40000000",
  USDC_DECIMALS
);

const MAX_LONG_CAPACITY = ethers.utils.parseUnits("15000", ETH_DECIMALS);
const MAX_SHORT_CAPACITY = ethers.utils.parseUnits("15000", ETH_DECIMALS);

describe("Place and Execute Market Order", function () {
  async function getContext() {
    const ctx = await loadFixture(deployForTest);
    console.log(
      "\n-------------------- Contracts Deployed. --------------------\n"
    );
    return ctx;
  }

  async function _registerTokens(ctx: any) {
    // register & set token data (USDC)
    await ctx.tokenInfo.registerToken(ctx.testUSDC, USDC_DECIMALS);
    const testUSDCAssetId = await ctx.tokenInfo.getAssetIdFromTokenAddress(
      ctx.testUSDC
    );
    await ctx.tokenInfo.setSizeToPriceBufferDeltaMultiplier(
      testUSDCAssetId,
      USDC_MULTIPLIER
    );

    // register & set token data (ETH)
    await ctx.tokenInfo.registerToken(ctx.weth, ETH_DECIMALS);
    const wethAssetId = await ctx.tokenInfo.getAssetIdFromTokenAddress(
      ctx.weth
    );
    await ctx.tokenInfo.setSizeToPriceBufferDeltaMultiplier(
      wethAssetId,
      ETH_MULTIPLIER
    );
  }

  // listing ETH/USDC perps market
  async function _listPerpMarket(ctx: any) {
    let m = {
      marketId: ETH_USDC_MARKET_ID,
      priceTickSize: ETH_USDC_MARKET_TICK_SIZE,
      baseAssetId: ETH_ID,
      quoteAssetId: USDC_ID,
      longReserveAssetId: ETH_ID,
      shortReserveAssetId: USDC_ID,
      marginAssetId: USDC_ID,
      fundingRateMultiplier: ETH_USDC_MARKET_FUNDING_RATE_MULTIPLIER,
    };

    await ctx.listingManager.createRisePerpsMarket(m);
  }

  // add liquidity (Long reserve token)
  async function _addLiquidities(ctx: any) {
    await ctx.risePool.addLiquidity(
      ETH_USDC_MARKET_ID,
      true,
      LONG_LIQUIDITY_AMOUNT
    );
    await ctx.risePool.addLiquidity(
      ETH_USDC_MARKET_ID,
      false,
      SHORT_LIQUIDITY_AMOUNT
    );
  }

  // deposit to trader account

  async function _depositMargin(ctx: any, amount: any) {
    await ctx.traderVault
      .connect(ctx.trader)
      .increaseTraderBalance(ctx.trader.address, USDC_ID, amount);
  }

  async function _setMarketMaxCapacities(ctx: any) {
    await ctx.positionVault.setMaxLongCapacity(
      ETH_USDC_MARKET_ID,
      MAX_LONG_CAPACITY
    );
    await ctx.positionVault.setMaxShortCapacity(
      ETH_USDC_MARKET_ID,
      MAX_SHORT_CAPACITY
    );
  }

  async function initialize(ctx: any) {
    await _registerTokens(ctx);
    await _listPerpMarket(ctx);
    await _addLiquidities(ctx);
    await _depositMargin(ctx, DEPOSIT_AMOUNT);
    await _setMarketMaxCapacities(ctx);
  }

  it("0. Initialize", async function () {
    const ctx = await getContext();
    await initialize(ctx);

    // registered token info
    const testUSDCAssetId = await ctx.tokenInfo.getAssetIdFromTokenAddress(
      ctx.testUSDC
    );
    const testUSDCDecimal = await ctx.tokenInfo.getTokenDecimals(
      testUSDCAssetId
    );
    const testUSDCPriceBufferDeltaMultiplier =
      await ctx.tokenInfo.getSizeToPriceBufferDeltaMultiplier(testUSDCAssetId);
    const wethAssetId = await ctx.tokenInfo.getAssetIdFromTokenAddress(
      ctx.weth
    );
    const wethDecimal = await ctx.tokenInfo.getTokenDecimals(wethAssetId);
    const wethPriceBufferDeltaMultiplier =
      await ctx.tokenInfo.getSizeToPriceBufferDeltaMultiplier(wethAssetId);

    expect(testUSDCAssetId).to.equal(USDC_ID);
    expect(testUSDCDecimal).to.equal(USDC_DECIMALS);
    expect(testUSDCPriceBufferDeltaMultiplier).to.equal(USDC_MULTIPLIER);
    expect(wethAssetId).to.equal(ETH_ID);
    expect(wethDecimal).to.equal(ETH_DECIMALS);
    expect(wethPriceBufferDeltaMultiplier).to.equal(ETH_MULTIPLIER);

    // perps market info
    const marketInfo = await ctx.market.getMarketInfo(ETH_USDC_MARKET_ID);
    expect(marketInfo.marketId).to.equal(ETH_USDC_MARKET_ID);
    expect(marketInfo.priceTickSize).to.equal(10 ** 8);
    expect(marketInfo.baseAssetId).to.equal(ETH_ID);
    expect(marketInfo.quoteAssetId).to.equal(USDC_ID);
    expect(marketInfo.longReserveAssetId).to.equal(ETH_ID);
    expect(marketInfo.shortReserveAssetId).to.equal(USDC_ID);
    expect(marketInfo.marginAssetId).to.equal(USDC_ID);
    expect(marketInfo.fundingRateMultiplier).to.equal(0);

    // pool liquidity
    const ethUsdcLongPoolAmount = await ctx.risePool.getLongPoolAmount(
      ETH_USDC_MARKET_ID
    );
    const ethUsdcShortPoolAmount = await ctx.risePool.getShortPoolAmount(
      ETH_USDC_MARKET_ID
    );
    expect(ethUsdcLongPoolAmount).to.equal(LONG_LIQUIDITY_AMOUNT);
    expect(ethUsdcShortPoolAmount).to.equal(SHORT_LIQUIDITY_AMOUNT);

    // trader margin balance
    const traderBalance = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );
    expect(traderBalance).to.equal(DEPOSIT_AMOUNT);

    // market max cap
    const maxLongCapacity = await ctx.positionVault.maxLongCapacity(
      ETH_USDC_MARKET_ID
    );
    const maxShortCapacity = await ctx.positionVault.maxShortCapacity(
      ETH_USDC_MARKET_ID
    );
    expect(maxLongCapacity).to.equal(MAX_LONG_CAPACITY);
    expect(maxShortCapacity).to.equal(MAX_SHORT_CAPACITY);
  });

  it("1. Execute market order", async function () {
    const ctx = await getContext();
    await initialize(ctx);

    const traderBalance0 = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );
    console.log("traderBalance:", formatUSDC(traderBalance0), "USDC");
    expect(traderBalance0).to.equal(DEPOSIT_AMOUNT);

    // set price
    await ctx.priceManager.setPrice(
      ETH_USDC_MARKET_ID,
      ethers.utils.parseUnits("1950", USDC_DECIMALS)
    ); // 1950 USD per ETH

    console.log(
      "\n--------------------- Increase Long Position ---------------------\n"
    );

    const orderRequest1 = {
      trader: ctx.trader.address,
      isLong: true,
      isIncrease: true,
      orderType: 0, // TODO:check solidity enum
      marketId: ETH_USDC_MARKET_ID,
      sizeAbs: ethers.utils.parseUnits("100", ETH_DECIMALS),
      marginAbs: ethers.utils.parseUnits("10000", USDC_DECIMALS),
      limitPrice: 0,
    };

    // (temp) get Mark Price
    const markPrice1 = await ctx.priceManager.getMarkPrice(ETH_USDC_MARKET_ID);

    // before the market order submission
    expect(markPrice1).to.equal(ethers.utils.parseUnits("1950", USDC_DECIMALS));

    await ctx.orderRouter.connect(ctx.trader).placeMarketOrder(orderRequest1);

    const priceBuffer1 = await ctx.priceManager.getPriceBuffer(
      ETH_USDC_MARKET_ID
    );
    expect(priceBuffer1).to.equal(
      ethers.utils.parseUnits("0.01", PRICE_BUFFER_DECIMALS)
    );

    // (temp) get Mark Price
    const markPrice2 = await ctx.priceManager.getMarkPrice(ETH_USDC_MARKET_ID);
    expect(markPrice2).to.be.equal(
      ethers.utils.parseUnits("1969.5", USDC_DECIMALS)
    );

    const key1 = await ctx.orderUtils._getPositionKey(
      ctx.trader.address,
      true, // isLong
      ETH_USDC_MARKET_ID
    );

    const position1 = await ctx.positionVault.getPosition(key1);
    console.log("\nposition:", formatPosition(position1));

    expect(position1.avgOpenPrice).to.be.equal(
      ethers.utils.parseUnits("1959.75", USDC_DECIMALS)
    );

    const orderRecord1 = await ctx.orderHistory.orderRecords(
      ctx.trader.address,
      0 // TODO:효율적으로 record ID를 트래킹하는 방법 필요
    ); // traderAddress, traderOrderRecordId
    console.log("\norderRecord:", formatOrderRecord(orderRecord1));

    expect(orderRecord1.executionPrice).to.be.equal(
      ethers.utils.parseUnits("1959.75", USDC_DECIMALS)
    );

    /// avgExecPrice
    /// indexPrice = 1950
    /// priceBuffer = 0.01 => 19.5
    /// avgPriceBuffer = {(Last Long Short OI Diff) + (priceBuffer) / 2} => 9.75

    const globalPositionState1 =
      await ctx.globalState.getGlobalLongPositionState(ETH_USDC_MARKET_ID);
    console.log(
      "\nglobalPositionState:",
      formatGlobalPositionState(globalPositionState1)
    );

    expect(globalPositionState1.totalSize).to.be.equal(
      ethers.utils.parseUnits("100", ETH_DECIMALS)
    );
    expect(globalPositionState1.totalMargin).to.be.equal(
      ethers.utils.parseUnits("10000", USDC_DECIMALS)
    );
    expect(globalPositionState1.avgPrice).to.be.equal(
      ethers.utils.parseUnits("1959.75", USDC_DECIMALS)
    );

    const traderBalance1 = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );

    expect(traderBalance1).to.be.equal(
      DEPOSIT_AMOUNT.sub(ethers.utils.parseUnits("10000", USDC_DECIMALS))
    );

    const tokenReserveAmount1 = await ctx.risePool.getLongReserveAmount(
      ETH_USDC_MARKET_ID
    );

    console.log("\ntokenReserveAmount:", formatETH(tokenReserveAmount1), "ETH");

    expect(tokenReserveAmount1).to.be.equal(
      ethers.utils.parseUnits("100", ETH_DECIMALS)
    );

    const positionRecord1 = await ctx.positionHistory.positionRecords(
      ctx.trader.address,
      0
    ); // traderAddress, traderPositionRecordId

    console.log("\npositionRecord:", formatPositionRecord(positionRecord1));

    // check avgOpenPrice
    expect(positionRecord1.avgOpenPrice).to.be.equal(
      ethers.utils.parseUnits("1959.75", USDC_DECIMALS)
    );
    // check avgClose Price
    expect(positionRecord1.avgClosePrice).to.be.equal(
      ethers.utils.parseUnits("0", USDC_DECIMALS)
    );

    console.log(
      "\n---------------------- Decrease Long Position ----------------------\n"
    );

    // priceBuffer not changed at this point
    const priceBuffer2 = await ctx.priceManager.getPriceBuffer(
      ETH_USDC_MARKET_ID
    );
    expect(priceBuffer2).to.equal(
      ethers.utils.parseUnits("0.01", PRICE_BUFFER_DECIMALS)
    );

    const markPrice3 = await ctx.priceManager.getMarkPrice(ETH_USDC_MARKET_ID);

    // before the market order submission
    // Global Mark Price not has been changed as well
    expect(markPrice3).to.equal(
      ethers.utils.parseUnits("1969.5", USDC_DECIMALS)
    );

    // set price
    await ctx.priceManager.setPrice(
      ETH_USDC_MARKET_ID,
      ethers.utils.parseUnits("1965", USDC_DECIMALS)
    ); // 1950 USD per ETH

    // 1965 * (1 + 0.01) = 1986.65

    const markPrice4 = await ctx.priceManager.getMarkPrice(ETH_USDC_MARKET_ID);

    expect(markPrice4).to.equal(
      ethers.utils.parseUnits("1984.65", USDC_DECIMALS)
    );

    const orderRequest2 = {
      trader: ctx.trader.address,
      isLong: true,
      isIncrease: false,
      orderType: 0,
      marketId: ETH_USDC_MARKET_ID,
      sizeAbs: ethers.utils.parseUnits("50", ETH_DECIMALS),
      marginAbs: 0, // TODO:check:need to set marginAbs for decreasing position?
      limitPrice: 0,
    };

    await ctx.orderRouter.connect(ctx.trader).placeMarketOrder(orderRequest2);

    // (Long OI - Short OI) = 50
    // price buffer = 0.005 (after the order)
    const priceBuffer3 = await ctx.priceManager.getPriceBuffer(
      ETH_USDC_MARKET_ID
    );
    expect(priceBuffer3).to.equal(
      ethers.utils.parseUnits("0.005", PRICE_BUFFER_DECIMALS)
    );

    const key2 = await ctx.orderUtils._getPositionKey(
      ctx.trader.address,
      true, // isLong
      ETH_USDC_MARKET_ID
    );

    const position2 = await ctx.positionVault.getPosition(key2);
    console.log("\nposition:", formatPosition(position2));

    const orderRecord2 = await ctx.orderHistory.orderRecords(
      ctx.trader.address,
      1
    ); // traderAddress, traderOrderRecordId
    console.log("\norderRecord:", formatOrderRecord(orderRecord2));

    // last price buffer = 0.01
    // price buffer change = -0.005
    // average price buffer = (0.01 - 0.005) / 2 = 0.0025
    // avgExecPrice = 1965 * (1 + 0.0025) = 1969.9125
    expect(orderRecord2.executionPrice).to.be.equal(
      ethers.utils.parseUnits("1969.9125", USDC_DECIMALS)
    );

    const globalPositionState2 =
      await ctx.globalState.getGlobalLongPositionState(ETH_USDC_MARKET_ID);
    console.log(
      "\nglobalPositionState:",
      formatGlobalPositionState(globalPositionState2)
    );

    expect(globalPositionState2.totalSize).to.be.equal(
      ethers.utils.parseUnits("50", ETH_DECIMALS)
    );
    expect(globalPositionState2.totalMargin).to.be.equal(
      ethers.utils.parseUnits("10000", USDC_DECIMALS)
    );

    // GlobalPositionState avgPrice doesn't change for decreasing positions
    expect(globalPositionState2.avgPrice).to.be.equal(
      ethers.utils.parseUnits("1959.75", USDC_DECIMALS)
    );

    const tokenReserveAmount2 = await ctx.risePool.getLongReserveAmount(
      ETH_USDC_MARKET_ID
    );
    console.log("\ntokenReserveAmount:", formatETH(tokenReserveAmount2), "ETH");

    const positionRecord2 = await ctx.positionHistory.positionRecords(
      ctx.trader.address,
      0
    ); // traderAddress, traderPositionRecordId
    console.log("\npositionRecord:", formatPositionRecord(positionRecord2));

    // check avgOpenPrice
    expect(positionRecord2.avgOpenPrice).to.be.equal(
      ethers.utils.parseUnits("1959.75", USDC_DECIMALS)
    );
    // check avgClose Price
    expect(positionRecord2.avgClosePrice).to.be.equal(
      ethers.utils.parseUnits("1969.9125", USDC_DECIMALS)
    );

    // check pnl
    // TODO: FIXME: check if (Execution Price - Avg Open Price) is correct
    // pnl = (Execution Price - Avg Open Price) * (Closed Size) for Long position
    // = (1969.9125 - 1959.75) * 50 = + 508.125 (USDC)
    expect(positionRecord2.cumulativeRealizedPnl).to.be.equal(
      ethers.utils.parseUnits("508.125", USDC_DECIMALS)
    );

    const traderBalance2 = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );
    console.log("traderBalance:", formatUSDC(traderBalance2), "USDC");

    // trader balance = 500000 - 10000 + 508.125 = 490508.125
    expect(traderBalance2).to.be.equal(
      ethers.utils.parseUnits("490508.125", USDC_DECIMALS)
    );

    console.log(
      "\n--------------------- Close Long Position ---------------------\n"
    );

    // set price
    await ctx.priceManager.setPrice(
      ETH_USDC_MARKET_ID,
      ethers.utils.parseUnits("1970", USDC_DECIMALS)
    ); // 1950 USD per ETH

    // FIXME: TODO: `Close` order type ?
    const orderRequest3 = {
      trader: ctx.trader.address,
      isLong: true,
      isIncrease: false,
      orderType: 0,
      marketId: ETH_USDC_MARKET_ID,
      sizeAbs: ethers.utils.parseUnits("50", ETH_DECIMALS),
      marginAbs: ethers.utils.parseUnits("10000", USDC_DECIMALS), // TODO:check:need to set marginAbs for decreasing position?
      limitPrice: 0,
    };

    await ctx.orderRouter.connect(ctx.trader).placeMarketOrder(orderRequest3);

    // (Long OI - Short OI) = 0
    // price buffer = 0 (after the order)
    const priceBuffer4 = await ctx.priceManager.getPriceBuffer(
      ETH_USDC_MARKET_ID
    );
    expect(priceBuffer4).to.equal(0);

    const key3 = await ctx.orderUtils._getPositionKey(
      ctx.trader.address,
      true, // isLong
      ETH_USDC_MARKET_ID
    );

    const position3 = await ctx.positionVault.getPosition(key3);
    console.log("\nposition:", formatPosition(position3));

    const orderRecord3 = await ctx.orderHistory.orderRecords(
      ctx.trader.address,
      2
    ); // traderAddress, traderOrderRecordId
    console.log("\norderRecord:", formatOrderRecord(orderRecord3));

    // last price buffer = 0.05 (롱 50)
    // price buffer change = -0.05 (롱 50 제거)
    // average price buffer = (0.005 - 0.005) / 2 = 0
    // avgExecPrice = 1970 * (1 + 0) = 1970
    expect(orderRecord3.executionPrice).to.be.equal(
      ethers.utils.parseUnits("1970", USDC_DECIMALS)
    );
    const positionRecord3 = await ctx.positionHistory.positionRecords(
      ctx.trader.address,
      0
    ); // traderAddress, traderPositionRecordId
    console.log("\npositionRecord:", formatPositionRecord(positionRecord3));

    // check avgOpenPrice
    expect(positionRecord3.avgOpenPrice).to.be.equal(
      ethers.utils.parseUnits("1959.75", USDC_DECIMALS)
    );
    // check avgClose Price
    // 1. closed 50 ETH in price 1969.9125
    // 2. closed 50 ETH in price 1970
    expect(positionRecord3.avgClosePrice).to.be.equal(
      ethers.utils.parseUnits("1969.95625", USDC_DECIMALS)
    );

    // check pnl
    // pnl = (Execution Price - Avg Open Price) * (Closed Size) for Long position
    // = (1970 - 1959.75) * 50 = + 512.5 (USDC)
    // cumulativePnl = 508.125 + 512.5 = 1020.625
    expect(positionRecord3.cumulativeRealizedPnl).to.be.equal(
      ethers.utils.parseUnits("1020.625", USDC_DECIMALS)
    );

    const traderBalance3 = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );
    console.log("traderBalance:", formatUSDC(traderBalance3), "USDC");

    // trader balance = 500000 - 10000 + 508.125 + 512.5 + 100000 (margin) = 501020.625
    expect(traderBalance3).to.be.equal(
      ethers.utils.parseUnits("501020.625", USDC_DECIMALS)
    );
  });
});
