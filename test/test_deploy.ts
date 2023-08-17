import { ethers } from "hardhat";

import { deployContract } from "../utils/deployer";
import { Network } from "../utils/network";
import { getLibraryAddress } from "../utils/getLibraryAddress";
import { getContractAddress } from "../utils/getContractAddress";
import { getPresetAddress } from "../utils/getPresetAddress";

export async function deployForTest() {
  const [deployer, keeper, trader] = await ethers.getSigners();

  const weth = getPresetAddress("WETH");
  const testUSDC = getContractAddress("TestUSDC", Network.L2);
  const l2MarginGateway = getContractAddress("L2MarginGateway", Network.L2);
  const l2LiquidityGateway = getContractAddress(
    "L2LiquidityGateway",
    Network.L2
  );

  // L3 libraries
  const mathUtils = await deployContract("MathUtils");
  const orderUtils = await deployContract("OrderUtils");
  const positionUtils = await deployContract("PositionUtils", [], {
    MathUtils: mathUtils.address,
  });
  const pnlUtils = await deployContract("PnlUtils");

  // TraderVault
  const traderVault = await deployContract("TraderVault");

  // Market
  const market = await deployContract("Market");

  // TokenInfo
  const tokenInfo = await deployContract("TokenInfo", [market.address]);

  // ListingManager
  const listingManager = await deployContract("ListingManager", [
    market.address,
  ]);

  // RisePool
  const risePool = await deployContract("RisePool");

  // GlobalState
  const globalState = await deployContract("GlobalState", [], {
    PositionUtils: positionUtils.address,
  });

  // L3Gateway
  const l3Gateway = await deployContract("L3Gateway", [
    traderVault.address,
    tokenInfo.address,
    risePool.address,
    market.address,
    l2MarginGateway,
    l2LiquidityGateway,
  ]);

  // PriceManager
  const priceManager = await deployContract("PriceManager", [
    globalState.address,
    tokenInfo.address,
  ]);

  // PriceFetcher
  const priceFetcher = await deployContract("PriceFetcher", [
    priceManager.address,
  ]);

  // Liquidation
  const liquidation = await deployContract(
    "Liquidation",
    [
      priceManager.address,
      traderVault.address,
      tokenInfo.address,
      market.address,
    ],
    {
      MathUtils: mathUtils.address,
    }
  );

  // Funding
  const funding = await deployContract(
    "Funding",
    [
      priceManager.address,
      globalState.address,
      tokenInfo.address,
      market.address,
    ],
    {
      MathUtils: mathUtils.address,
      OrderUtils: orderUtils.address,
    }
  );

  // PositionVault
  const positionVault = await deployContract(
    "PositionVault",
    [funding.address],
    { PositionUtils: positionUtils.address }
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
    { PositionUtils: positionUtils.address }
  );

  // PositionFee
  const positionFee = await deployContract("PositionFee", [
    traderVault.address,
  ]);

  // PositionManager
  const positionManager = await deployContract(
    "PositionManager",
    [positionVault.address, market.address],
    { OrderUtils: orderUtils.address, PnlUtils: pnlUtils.address }
  );

  // MarketOrder
  const marketOrder = await deployContract(
    "MarketOrder",
    [
      traderVault.address,
      risePool.address,
      funding.address,
      market.address,
      positionHistory.address,
      positionVault.address,
      orderValidator.address,
      orderHistory.address,
      priceFetcher.address,
      globalState.address,
      positionFee.address,
    ],
    {
      OrderUtils: orderUtils.address,
      PnlUtils: pnlUtils.address,
    }
  );

  // OrderBook
  const orderBook = await deployContract(
    "OrderBook",
    [
      traderVault.address,
      risePool.address,
      funding.address,
      market.address,
      positionHistory.address,
      positionVault.address,
      priceFetcher.address,
      positionFee.address,
    ],
    {
      MathUtils: mathUtils.address,
      OrderUtils: orderUtils.address,
      PnlUtils: pnlUtils.address,
    }
  );

  // OrderRouter
  const orderRouter = await deployContract("OrderRouter", [
    marketOrder.address,
    orderBook.address,
  ]);

  // PriceMaster
  const priceMaster = await deployContract("PriceMaster", [
    priceManager.address,
    orderBook.address,
    keeper.address, // price keeper
  ]);

  // L3 initialization
  // await tokenInfo.registerToken(testUsdcAddress, 18);

  return {
    deployer,
    keeper,
    trader,
    mathUtils,
    positionUtils,
    orderUtils,
    pnlUtils,
    weth,
    l2MarginGateway,
    l2LiquidityGateway,
    testUSDC,
    traderVault,
    market,
    tokenInfo,
    listingManager,
    risePool,
    globalState,
    l3Gateway,
    priceManager,
    priceFetcher,
    liquidation,
    funding,
    positionVault,
    orderValidator,
    orderHistory,
    positionHistory,
    positionFee,
    positionManager,
    marketOrder,
    orderBook,
    orderRouter,
    priceMaster,
  };
}
