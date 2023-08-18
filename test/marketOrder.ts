import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { deployForTest } from "./test_deploy";
import {
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
const PRICE_BUFFER_DECIMALS = 8;
const PRICE_BUFFER_DELTA_MULTIPLIER_DECIMALS = 10;

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
      ethers.utils.parseUnits("1", PRICE_BUFFER_DELTA_MULTIPLIER_DECIMALS) // TODO: set -> need multiplier for USDC?
    );

    // register & set token data (ETH)
    await ctx.tokenInfo.registerToken(ctx.weth, ETH_DECIMALS);
    const wethAssetId = await ctx.tokenInfo.getAssetIdFromTokenAddress(
      ctx.weth
    );
    await ctx.tokenInfo.setSizeToPriceBufferDeltaMultiplier(
      wethAssetId,
      ethers.utils.parseUnits("0.0001", PRICE_BUFFER_DELTA_MULTIPLIER_DECIMALS) // TODO: set
    );
  }

  // listing ETH/USDC perps market
  async function _listPerpMarket(ctx: any) {
    let m = {
      marketId: ETH_USDC_MARKET_ID,
      priceTickSize: 10 ** 8,
      baseAssetId: ETH_ID,
      quoteAssetId: USDC_ID,
      longReserveAssetId: ETH_ID,
      shortReserveAssetId: USDC_ID,
      marginAssetId: USDC_ID,
      fundingRateMultiplier: 0,
    };

    await ctx.listingManager.createRisePerpsMarket(m);
  }

  // add liquidity (Long reserve token)
  async function _addLiquidities(ctx: any) {
    await ctx.risePool.addLiquidity(
      ETH_USDC_MARKET_ID,
      true,
      ethers.utils.parseUnits("20000", ETH_DECIMALS)
    );
    await ctx.risePool.addLiquidity(
      ETH_USDC_MARKET_ID,
      false,
      ethers.utils.parseUnits("40000000", USDC_DECIMALS)
    );
  }

  // deposit to trader account
  async function _depositMargin(ctx: any) {
    await _depositToTraderAccount(ctx.traderVault, ctx.trader, "500000");
  }
  async function _depositToTraderAccount(
    traderVault: any,
    trader: any,
    amount: string
  ) {
    const depositAmount = ethers.utils.parseUnits(amount, USDC_DECIMALS); // 5000 USD
    await traderVault
      .connect(trader)
      .increaseTraderBalance(trader.address, USDC_ID, depositAmount);
  }

  async function _setMarketMaxCapacities(ctx: any) {
    await ctx.positionVault.setMaxLongCapacity(
      ETH_USDC_MARKET_ID,
      ethers.utils.parseUnits("15000", ETH_DECIMALS)
    );
    await ctx.positionVault.setMaxShortCapacity(
      ETH_USDC_MARKET_ID,
      ethers.utils.parseUnits("15000", ETH_DECIMALS)
    );
  }

  async function initialize(ctx: any) {
    await _registerTokens(ctx);
    await _listPerpMarket(ctx);
    await _addLiquidities(ctx);
    await _depositMargin(ctx);
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
    expect(testUSDCPriceBufferDeltaMultiplier).to.equal(
      ethers.utils.parseUnits("1", PRICE_BUFFER_DELTA_MULTIPLIER_DECIMALS)
    );
    expect(wethAssetId).to.equal(ETH_ID);
    expect(wethDecimal).to.equal(ETH_DECIMALS);
    expect(wethPriceBufferDeltaMultiplier).to.equal(
      ethers.utils.parseUnits("0.0001", PRICE_BUFFER_DELTA_MULTIPLIER_DECIMALS)
    );

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
    expect(ethUsdcLongPoolAmount).to.equal(
      ethers.utils.parseUnits("20000", ETH_DECIMALS)
    );
    expect(ethUsdcShortPoolAmount).to.equal(
      ethers.utils.parseUnits("40000000", USDC_DECIMALS)
    );

    // trader margin balance
    const traderBalance = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );
    expect(traderBalance).to.equal(
      ethers.utils.parseUnits("500000", USDC_DECIMALS)
    );

    // market max cap
    const maxLongCapacity = await ctx.positionVault.maxLongCapacity(
      ETH_USDC_MARKET_ID
    );
    const maxShortCapacity = await ctx.positionVault.maxShortCapacity(
      ETH_USDC_MARKET_ID
    );
    expect(maxLongCapacity).to.equal(
      ethers.utils.parseUnits("15000", ETH_DECIMALS)
    );
    expect(maxShortCapacity).to.equal(
      ethers.utils.parseUnits("15000", ETH_DECIMALS)
    );
  });

  it("1. Execute market order", async function () {
    const ctx = await getContext();
    await initialize(ctx);

    const traderBalance0 = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );
    console.log(">>> traderBalance: ", formatUSDC(traderBalance0));

    // set price
    await ctx.priceManager.setPrice(
      ETH_USDC_MARKET_ID,
      ethers.utils.parseUnits("1950", USDC_DECIMALS)
    ); // 1950 USD per ETH

    console.log("-------------------- Increase Position --------------------");

    const orderRequest1 = {
      trader: ctx.trader.address,
      isLong: true,
      isIncrease: true,
      orderType: 0, // TODO: check solidity enum
      marketId: ETH_USDC_MARKET_ID,
      sizeAbs: ethers.utils.parseUnits("100", ETH_DECIMALS),
      marginAbs: ethers.utils.parseUnits("10000", USDC_DECIMALS),
      limitPrice: 0,
    };

    // (temp) get Mark Price
    const markPrice1 = await ctx.priceManager.getMarkPrice(ETH_USDC_MARKET_ID);
    console.log(
      ">>> mark price 1:",
      ethers.utils.formatUnits(markPrice1, USDC_DECIMALS)
    );

    await ctx.orderRouter.connect(ctx.trader).placeMarketOrder(orderRequest1);
    // position 생성
    // order record 생성
    // global position state 업데이트
    // position fee 지불
    // trader balance 차감
    // token reserve amount 증가
    // position record 생성

    // (temp) get Mark Price
    const markPrice2 = await ctx.priceManager.getMarkPrice(ETH_USDC_MARKET_ID);
    console.log(
      ">>> mark price 2:",
      ethers.utils.formatUnits(markPrice2, USDC_DECIMALS)
    );

    const key1 = await ctx.orderUtils._getPositionKey(
      ctx.trader.address,
      true, // isLong
      ETH_USDC_MARKET_ID
    );

    const position1 = await ctx.positionVault.getPosition(key1);
    console.log(">>> position: ", formatPosition(position1));

    const orderRecord1 = await ctx.orderHistory.orderRecords(
      ctx.trader.address,
      0 // TODO: 효율적으로 record ID를 트래킹하는 방법 필요
    ); // traderAddress, traderOrderRecordId
    console.log(">>> orderRecord: ", formatOrderRecord(orderRecord1));

    const globalPositionState1 =
      await ctx.globalState.getGlobalLongPositionState(ETH_USDC_MARKET_ID);
    console.log(
      ">>> globalPositionState: ",
      formatGlobalPositionState(globalPositionState1)
    );

    const traderBalance1 = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );
    console.log(">>> traderBalance: ", formatUSDC(traderBalance1));

    const tokenReserveAmount1 = await ctx.risePool.getLongReserveAmount(
      ETH_USDC_MARKET_ID
    );
    console.log(">>> tokenReserveAmount: ", formatUSDC(tokenReserveAmount1));

    const positionRecord1 = await ctx.positionHistory.positionRecords(
      ctx.trader.address,
      0
    ); // traderAddress, traderPositionRecordId
    console.log(">>> positionRecord: ", formatPositionRecord(positionRecord1));

    // set price
    await ctx.priceManager.setPrice(
      ETH_USDC_MARKET_ID,
      ethers.utils.parseUnits("1965", USDC_DECIMALS)
    ); // 1950 USD per ETH

    console.log("-------------------- Decrease Position --------------------");

    const orderRequest2 = {
      trader: ctx.trader.address,
      isLong: true,
      isIncrease: false,
      orderType: 0,
      marketId: ETH_USDC_MARKET_ID,
      sizeAbs: ethers.utils.parseUnits("50", ETH_DECIMALS),
      marginAbs: 0, // TODO: check: need to set marginAbs for decreasing position?
      limitPrice: 0,
    };

    await ctx.orderRouter.connect(ctx.trader).placeMarketOrder(orderRequest2);

    const key2 = await ctx.orderUtils._getPositionKey(
      ctx.trader.address,
      true, // isLong
      ETH_USDC_MARKET_ID
    );

    const position2 = await ctx.positionVault.getPosition(key2);
    console.log(">>> position: ", formatPosition(position2));

    const orderRecord2 = await ctx.orderHistory.orderRecords(
      ctx.trader.address,
      1
    ); // traderAddress, traderOrderRecordId
    console.log(">>> orderRecord: ", formatOrderRecord(orderRecord2));

    const globalPositionState2 =
      await ctx.globalState.getGlobalLongPositionState(ETH_USDC_MARKET_ID);
    console.log(
      ">>> globalPositionState: ",
      formatGlobalPositionState(globalPositionState2)
    );

    const traderBalance2 = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );
    console.log(">>> traderBalance: ", formatUSDC(traderBalance2));

    const tokenReserveAmount2 = await ctx.risePool.getLongReserveAmount(
      ETH_USDC_MARKET_ID
    );
    console.log(">>> tokenReserveAmount: ", formatUSDC(tokenReserveAmount2));

    const positionRecord2 = await ctx.positionHistory.positionRecords(
      ctx.trader.address,
      0
    ); // traderAddress, traderPositionRecordId
    console.log(">>> positionRecord: ", formatPositionRecord(positionRecord2));
  });
});
