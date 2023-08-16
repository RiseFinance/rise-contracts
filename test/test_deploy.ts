import { ethers } from "hardhat";

import { deployContract } from "../utils/deployer";
import { Network } from "../utils/network";
import { getLibraryAddress } from "../utils/getLibraryAddress";
import { getContractAddress } from "../utils/getContractAddress";
import { getPresetAddress } from "../utils/getPresetAddress";

export async function deployForTest() {
  const [deployer, keeper, trader] = await ethers.getSigners();

  const mathUtils = getLibraryAddress("MathUtils"); // library
  const l2MarginGateway = getContractAddress("L2MarginGateway", Network.L2);
  const l2LiquidityGateway = getContractAddress(
    "L2LiquidityGateway",
    Network.L2
  );

  // TraderVault
  const traderVault = await deployContract("TraderVault");

  // Market
  const market = await deployContract("Market");

  // TokenInfo
  const tokenInfo = await deployContract("TokenInfo", [market.address]);

  // RisePool
  const risePool = await deployContract("RisePool");

  // GlobalState
  const globalState = await deployContract("GlobalState", [], mathUtils);

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

  // Funding
  const funding = await deployContract(
    "Funding",
    [
      priceManager.address,
      globalState.address,
      tokenInfo.address,
      market.address,
    ],
    mathUtils
  );

  // PositionVault
  const positionVault = await deployContract(
    "PositionVault",
    [funding.address],
    mathUtils
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
    mathUtils
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
    mathUtils
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
    keeper, // price keeper
  ]);

  // L3 initialization
  // await tokenInfo.registerToken(testUsdcAddress, 18);

  return {
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
    priceRouter,
  };
}
