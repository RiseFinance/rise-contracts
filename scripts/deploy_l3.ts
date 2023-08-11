import { deployContract } from "../utils/deployer";

export async function deployL3Contracts(
  _mathUtils: string, // library
  _l2MarginGateway: string,
  _l2LiquidityGateway: string,
  _keeper: string
) {
  // TraderVault
  const traderVault = await deployContract("TraderVault");

  // Market
  const market = await deployContract("Market");

  // TokenInfo
  const tokenInfo = await deployContract("TokenInfo", [market.address]);

  // RisePool
  const risePool = await deployContract("RisePool");

  // GlobalState
  const globalState = await deployContract("GlobalState", [], _mathUtils);

  // L3Gateway
  const l3Gateway = await deployContract("L3Gateway", [
    traderVault.address,
    tokenInfo.address,
    risePool.address,
    market.address,
    _l2MarginGateway,
    _l2LiquidityGateway,
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
    _mathUtils
  );

  // PositionVault
  const positionVault = await deployContract(
    "PositionVault",
    [funding.address],
    _mathUtils
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
    _mathUtils
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
    _mathUtils
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
    _keeper  // price keeper
  ]);

  console.log("---------------------------------------------");
  console.log(">>> L3 Contracts Deployed:");
  console.log("TraderVault: ", traderVault.address);
  console.log("Market: ", market.address);
  console.log("TokenInfo: ", tokenInfo.address);
  console.log("RisePool: ", risePool.address);
  console.log("L3Gateway: ", l3Gateway.address);
  console.log("PositionVault: ", positionVault.address);
  console.log("GlobalState: ", globalState.address);
  console.log("OrderValidator: ", orderValidator.address);
  console.log("OrderHistory: ", orderHistory.address);
  console.log("PositionHistory: ", positionHistory.address);
  console.log("MarketOrder: ", marketOrder.address);
  console.log("OrderBook: ", orderBook.address);
  console.log("OrderRouter: ", orderRouter.address);
  console.log("PriceRouter: ", priceRouter.address);
  console.log("---------------------------------------------");

  return [l3Gateway, priceManager, orderBook];
}
