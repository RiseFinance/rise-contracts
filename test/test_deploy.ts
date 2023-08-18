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
  const mathUtils = await deployContract("MathUtils", [], undefined, true);
  const orderUtils = await deployContract("OrderUtils");
  const positionUtils = await deployContract(
    "PositionUtils",
    [],
    {
      MathUtils: mathUtils.address,
    },
    true
  );
  const pnlUtils = await deployContract("PnlUtils", [], undefined, true);

  // TraderVault
  const traderVault = await deployContract("TraderVault", [], undefined, true);

  // Market
  const market = await deployContract("Market", [], undefined, true);

  // TokenInfo
  const tokenInfo = await deployContract(
    "TokenInfo",
    [market.address],
    undefined,
    true
  );

  // ListingManager
  const listingManager = await deployContract(
    "ListingManager",
    [market.address],
    undefined,
    true
  );

  // RisePool
  const risePool = await deployContract("RisePool", [], undefined, true);

  // GlobalState
  const globalState = await deployContract(
    "GlobalState",
    [],
    {
      PositionUtils: positionUtils.address,
    },
    true
  );

  // L3Gateway
  const l3Gateway = await deployContract(
    "L3Gateway",
    [
      traderVault.address,
      tokenInfo.address,
      risePool.address,
      market.address,
      l2MarginGateway,
      l2LiquidityGateway,
    ],
    undefined,
    true
  );

  // PriceManager
  const priceManager = await deployContract(
    "PriceManager",
    [globalState.address, tokenInfo.address],
    undefined,
    true
  );

  // PriceFetcher
  const priceFetcher = await deployContract(
    "PriceFetcher",
    [priceManager.address],
    undefined,
    true
  );

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
    },
    true
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
    },
    true
  );

  // PositionVault
  const positionVault = await deployContract(
    "PositionVault",
    [funding.address],
    { PositionUtils: positionUtils.address },
    true
  );

  // OrderValidator
  const orderValidator = await deployContract(
    "OrderValidator",
    [positionVault.address, globalState.address, risePool.address],
    undefined,
    true
  );

  // OrderHistory
  const orderHistory = await deployContract(
    "OrderHistory",
    [traderVault.address],
    undefined,
    true
  );

  // PositionHistory
  const positionHistory = await deployContract(
    "PositionHistory",
    [positionVault.address, traderVault.address],
    { PositionUtils: positionUtils.address },
    true
  );

  // PositionFee
  const positionFee = await deployContract(
    "PositionFee",
    [traderVault.address],
    undefined,
    true
  );

  // PositionManager
  const positionManager = await deployContract(
    "PositionManager",
    [positionVault.address, market.address],
    { OrderUtils: orderUtils.address, PnlUtils: pnlUtils.address },
    true
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
    },
    true
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
    },
    true
  );

  // OrderRouter
  const orderRouter = await deployContract(
    "OrderRouter",
    [marketOrder.address, orderBook.address],
    undefined,
    true
  );

  // PriceMaster
  const priceMaster = await deployContract(
    "PriceMaster",
    [
      priceManager.address,
      orderBook.address,
      keeper.address, // price keeper
    ],
    undefined,
    true
  );

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
