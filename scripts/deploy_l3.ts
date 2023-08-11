import * as fs from "fs";
import { deployContract } from "../utils/deployer";
import { getContractAddress } from "../utils/getContractAddress";
import { getPresetAddress } from "../utils/getPresetAddress";

export type L3Addresses = {
  TraderVault: string;
  Market: string;
  TokenInfo: string;
  RisePool: string;
  GlobalState: string;
  L3Gateway: string;
  PriceManager: string;
  Funding: string;
  PositionVault: string;
  OrderValidator: string;
  OrderHistory: string;
  PositionHistory: string;
  MarketOrder: string;
  OrderBook: string;
  OrderRouter: string;
};

async function main() {
  await deployL3Contracts();
}

async function deployL3Contracts(): Promise<L3Addresses> {
  const mathUtils = await getContractAddress("MathUtils"); // library
  const l2MarginGateway = await getContractAddress("L2MarginGateway");
  const l2LiquidityGateway = await getContractAddress("L2LiquidityGateway");
  const keeper = await getPresetAddress("keeper");

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

  console.log("---------------------------------------------");
  console.log(">>> L3 Contracts Deployed:");
  console.log("TraderVault: ", traderVault.address);
  console.log("Market: ", market.address);
  console.log("TokenInfo: ", tokenInfo.address);
  console.log("RisePool: ", risePool.address);
  console.log("GlobalState: ", globalState.address);
  console.log("L3Gateway: ", l3Gateway.address);
  console.log("PriceManager: ", priceManager.address);
  console.log("Funding: ", funding.address);
  console.log("PositionVault: ", positionVault.address);
  console.log("OrderValidator: ", orderValidator.address);
  console.log("OrderHistory: ", orderHistory.address);
  console.log("PositionHistory: ", positionHistory.address);
  console.log("MarketOrder: ", marketOrder.address);
  console.log("OrderBook: ", orderBook.address);
  console.log("OrderRouter: ", orderRouter.address);
  console.log("PriceRouter: ", priceRouter.address);
  console.log("---------------------------------------------");

  const l3Addresses = {
    TraderVault: traderVault.address,
    Market: market.address,
    TokenInfo: tokenInfo.address,
    RisePool: risePool.address,
    GlobalState: globalState.address,
    L3Gateway: l3Gateway.address,
    PriceManager: priceManager.address,
    Funding: funding.address,
    PositionVault: positionVault.address,
    OrderValidator: orderValidator.address,
    OrderHistory: orderHistory.address,
    PositionHistory: positionHistory.address,
    MarketOrder: marketOrder.address,
    OrderBook: orderBook.address,
    OrderRouter: orderRouter.address,
    PriceRouter: priceRouter.address,
  };

  const libraryAddresses = JSON.parse(
    fs.readFileSync(__dirname + "/output/contractAddresses.json").toString()
  )["Library"];

  const l2Addresses = JSON.parse(
    fs.readFileSync(__dirname + "/output/contractAddresses.json").toString()
  )["L2"];

  fs.writeFileSync(
    __dirname + "/output/contractAddresses.json",
    JSON.stringify(
      { Library: libraryAddresses, L2: l2Addresses, L3: l3Addresses },
      null,
      2
    ),
    { flag: "w" }
  );

  return l3Addresses;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
