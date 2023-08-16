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

const USD_DECIMALS = 20;
const ETH_DECIMALS = 18;
const PRICE_BUFFER_DECIMALS = 8;

describe("Place and Execute Market Order", function () {
  async function depositToTraderAccount(
    traderVault: any,
    trader: any,
    amount: string
  ) {
    const depositAmount = ethers.utils.parseUnits(amount, USD_DECIMALS); // 5000 USD
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
    await depositToTraderAccount(ctx.traderVault, ctx.trader, "500000");

    const initialTraderBalance = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );

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
      ethers.utils.parseUnits("1950", USD_DECIMALS)
    ); // 1950 USD per ETH

    const orderRequest = {
      trader: ctx.trader.address,
      isLong: true,
      isIncrease: true,
      orderType: 0, // TODO: check solidity enum
      marketId: ETH_USDC_MARKET_ID,
      sizeAbs: ethers.utils.parseUnits("20000", ETH_DECIMALS),
      marginAbs: ethers.utils.parseUnits("1000", USD_DECIMALS),
      limitPrice: 0,
    };

    await ctx.orderRouter.connect(ctx.trader).placeMarketOrder(orderRequest);

    const key = await ctx.orderUtils._getPositionKey(
      ctx.trader.address,
      true, // isLong
      ETH_USDC_MARKET_ID
    );

    const position = await ctx.positionVault.getPosition(key);
    console.log(">>> position: ", formatPosition(position));

    const orderRecord = await ctx.orderHistory.orderRecords(
      ctx.trader.address,
      0
    ); // traderAddress, traderOrderRecordId
    console.log(">>> orderRecord: ", formatOrderRecord(orderRecord));

    const globalPositionState =
      await ctx.globalState.getGlobalLongPositionState(ETH_USDC_MARKET_ID);
    console.log(
      ">>> globalPositionState: ",
      formatGlobalPositionState(globalPositionState)
    );

    const traderBalance = await ctx.traderVault.getTraderBalance(
      ctx.trader.address,
      USDC_ID
    );
    console.log(">>> traderBalance: ", formatUSDC(traderBalance));

    const tokenReserveAmount = await ctx.risePool.getLongReserveAmount(
      ETH_USDC_MARKET_ID
    );
    console.log(">>> tokenReserveAmount: ", formatUSDC(tokenReserveAmount));

    const positionRecord = await ctx.positionHistory.positionRecords(
      ctx.trader.address,
      0
    ); // traderAddress, traderPositionRecordId
    console.log(">>> positionRecord: ", formatPositionRecord(positionRecord));

    // position 생성
    // order record 생성
    // global position state 업데이트
    // position fee 지불
    // trader balance 차감
    // token reserve amount 증가
    // position record 생성
  });
});
