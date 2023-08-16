import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { deployForTest } from "./test_deploy";

const USD_ID = 0;
const ETH_ID = 1;
const ETH_USD = 1;

const USD_DECIMALS = 20;
const ETH_DECIMALS = 18;
const PRICE_BUFFER_DECIMALS = 8;

/**
 *  const {
      deployer,
      keeper,
      trader,
      mathUtils,
      l2MarginGateway,
      l2LiquidityGateway,
      traderVault,
      market,
      tokenInfo,
      risePool,
      globalState,
      l3Gateway,
      priceManager,
      funding,
      positionVault,
      orderValidator,
      orderHistory,
      positionHistory,
      marketOrder,
      orderBook,
      orderRouter,
      priceMaster,
    } = await loadFixture(deployForTest);
 */

describe("Place and Execute Market Order", function () {
  async function depositToTraderAccount(traderVault: any, trader: any) {
    const depositAmount = ethers.utils.parseUnits("5000", USD_DECIMALS); // 5000 USD
    await traderVault
      .connect(trader)
      .increaseTraderBalance(trader.address, USD_ID, depositAmount);
  }

  async function getContext() {
    const ctx = await loadFixture(deployForTest);
    return ctx;
  }

  it("1. Execute market order", async function () {
    const ctx = await getContext();
    await depositToTraderAccount(ctx.traderVault, ctx.trader);

    let m = {
      marketId: ETH_USD,
      priceTickSize: 10 ** 8,
      baseAssetId: ETH_ID,
      quoteAssetId: USD_ID,
      longReserveAssetId: ETH_ID,
      shortReserveAssetId: USD_ID,
      marginAssetId: USD_ID,
      fundingRateMultiplier: 0,
      marketMakerToken: ctx.trader.address,
    };
    await ctx.listingManager.createRisePerpsMarket(m);

    // TODO: setup - register token & do market listing

    const orderRequest = {
      trader: ctx.trader.address,
      isLong: true,
      isIncrease: true,
      orderType: 0, // TODO: check solidity enum
      marketId: 0,
      sizeAbs: ethers.utils.parseUnits("20000", ETH_DECIMALS),
      marginAbs: ethers.utils.parseUnits("1000", USD_DECIMALS),
      limitPrice: 0,
    };
  });
});
