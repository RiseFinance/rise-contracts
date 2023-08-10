import { deployContract } from "../utils/deployer";

export async function deployL3Contracts() {
  const _l2MarginGateway = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9"; // FIXME:
  const _l2LiquidityGateway = "0x0165878A594ca255338adfa4d48449f69242Eb8F"; // FIXME:

  // TraderVault
  const traderVault = await deployContract("TraderVault");

  // Market
  const market = await deployContract("Market");

  // TokenInfo
  const tokenInfo = await deployContract("TokenInfo", [market.address]);

  // RisePool
  const risePool = await deployContract("RisePool");

  // L3Gateway
  const l3Gateway = await deployContract("L3Gateway", [
    traderVault.address,
    tokenInfo.address,
    risePool.address,
    market.address,
    _l2MarginGateway,
    _l2LiquidityGateway,
  ]);

  // PositionVault
  const positionVault = await deployContract("PositionVault");

  // GlobalState
  const globalState = await deployContract("GlobalState");

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
  const positionHistory = await deployContract("PositionHistory", [
    positionVault.address,
    traderVault.address,
  ]);

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
  const orderBook = await deployContract("OrderBook", [
    traderVault.address,
    risePool.address,
    market.address,
    positionHistory.address,
    positionVault.address,
  ]);

  // OrderRouter
  const orderRouter = await deployContract("OrderRouter", [
    marketOrder.address,
    orderBook.address,
  ]);

  console.log("---------------------------------------------");
  console.log(">>> L3 Contracts Deployed.");
  console.log(">>> TraderVault: ", traderVault.address);
  console.log(">>> Market: ", market.address);
  console.log(">>> TokenInfo: ", tokenInfo.address);
  console.log(">>> RisePool: ", risePool.address);
  console.log(">>> L3Gateway: ", l3Gateway.address);
  console.log(">>> PositionVault: ", positionVault.address);
  console.log(">>> GlobalState: ", globalState.address);
  console.log(">>> OrderValidator: ", orderValidator.address);
  console.log(">>> OrderHistory: ", orderHistory.address);
  console.log(">>> PositionHistory: ", positionHistory.address);
  console.log(">>> MarketOrder: ", marketOrder.address);
  console.log(">>> OrderBook: ", orderBook.address);
  console.log(">>> OrderRouter: ", orderRouter.address);
  console.log("---------------------------------------------");
}
