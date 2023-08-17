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

describe("Place and Execute Market Order", function () {
  async function depositToTraderAccount(
    traderVault: any,
    trader: any,
    amount: string
  ) {
    const depositAmount = ethers.utils.parseUnits(amount, USDC_DECIMALS); // 5000 USD
    await traderVault
      .connect(trader)
      .increaseTraderBalance(trader.address, USDC_ID, depositAmount);
  }

  async function getContext() {
    const ctx = await loadFixture(deployForTest);
    console.log(
      "\n-------------------- Contracts Deployed. --------------------\n"
    );
    return ctx;
  }

  it("1. Execute market order", async function () {
    const ctx = await getContext();

    // set token data (USDC)

    await ctx.tokenInfo.registerToken(ctx.testUSDC, USDC_DECIMALS);
    const testUSDCAssetId = await ctx.tokenInfo.getAssetIdFromTokenAddress(
      ctx.testUSDC
    );
    console.log(">>> testUSDCAssetId: ", testUSDCAssetId);
    await ctx.tokenInfo.setSizeToPriceBufferDeltaMultiplier(testUSDCAssetId, 1);

    // set token data (ETH)

    await ctx.tokenInfo.registerToken(ctx.weth, ETH_DECIMALS);
    const wethAssetId = await ctx.tokenInfo.getAssetIdFromTokenAddress(
      ctx.weth
    );
    console.log(">>> wethAssetId: ", wethAssetId);
    await ctx.tokenInfo.setSizeToPriceBufferDeltaMultiplier(wethAssetId, 1);

    // listing a perps market

    let m = {
      marketId: ETH_USDC_MARKET_ID,
      priceTickSize: 10 ** 8,
      baseAssetId: ETH_ID,
      quoteAssetId: USDC_ID,
      longReserveAssetId: ETH_ID,
      shortReserveAssetId: USDC_ID,
      marginAssetId: USDC_ID,
      fundingRateMultiplier: 0,
      marketMakerToken: ctx.trader.address, // temporary
    };
    await ctx.listingManager.createRisePerpsMarket(m);

    await depositToTraderAccount(ctx.traderVault, ctx.trader, "500000");

    const traderBalance0 = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );
    console.log(">>> traderBalance: ", formatUSDC(traderBalance0));

    const initialTraderBalance = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );

    await ctx.positionVault.setMaxLongCapacity(
      ETH_USDC_MARKET_ID,
      ethers.utils.parseUnits("15000000", ETH_DECIMALS)
    );
    await ctx.positionVault.setMaxShortCapacity(
      ETH_USDC_MARKET_ID,
      ethers.utils.parseUnits("15000000", ETH_DECIMALS)
    );

    // add liquidity (Long reserve token)

    await ctx.risePool.addLiquidity(
      ETH_USDC_MARKET_ID,
      true,
      ethers.utils.parseUnits("1000000", ETH_DECIMALS)
    );

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

    await ctx.orderRouter.connect(ctx.trader).placeMarketOrder(orderRequest1);
    // position 생성
    // order record 생성
    // global position state 업데이트
    // position fee 지불
    // trader balance 차감
    // token reserve amount 증가
    // position record 생성
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
