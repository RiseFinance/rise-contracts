// import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
// import { expect } from "chai";
// import { ethers } from "hardhat";
// import { deployContract } from "../utils/deployer";

// function fromUSD(amount: number) {
//   return ethers.utils.parseUnits(amount.toString(), 20);
// }
// function toUSD(amount: number) {
//   return ethers.utils.formatUnits(amount.toString(), 20);
// }

// async function deployContracts(
//   ) {
//     const [deployer, trader, priceKeeper] =  await ethers.getSigners();

//   const mathUtils = await deployContract("MathUtils");

//     // TraderVault
//     const traderVault = await deployContract("TraderVault");

//     const positionFee = await deployContract("PositionFee", [traderVault.address]);
//     // Market
//     const market = await deployContract("Market");

//     // TokenInfo
//     const tokenInfo = await deployContract("TokenInfo", [market.address]);

//     // RisePool
//     const risePool = await deployContract("RisePool");

//     // GlobalState
//     const globalState = await deployContract("GlobalState", [], mathUtils.address);

//     // PriceManager
//     const priceManager = await deployContract("PriceManager", [
//       globalState.address,
//       tokenInfo.address,
//       priceKeeper.address, // _keeperAddress
//     ]);
//     // Funding
//     const funding = await deployContract(
//       "Funding",
//       [
//         priceManager.address,
//         globalState.address,
//         tokenInfo.address,
//         market.address,
//       ],
//       mathUtils.address
//     );

//     // PositionVault
//     const positionVault = await deployContract(
//       "PositionVault",
//       [funding.address],
//       mathUtils.address
//     );

//     // OrderValidator
//     const orderValidator = await deployContract("OrderValidator", [
//       positionVault.address,
//       globalState.address,
//       risePool.address,
//     ]);

//     // OrderHistory
//     const orderHistory = await deployContract("OrderHistory", [
//       traderVault.address,
//     ]);

//     // PositionHistory
//     const positionHistory = await deployContract(
//       "PositionHistory",
//       [positionVault.address, traderVault.address],
//       mathUtils.address
//     );

//     // MarketOrder
//     const marketOrder = await deployContract("MarketOrder", [
//       traderVault.address,
//       risePool.address,
//       market.address,
//       positionHistory.address,
//       positionVault.address,
//       orderValidator.address,
//       orderHistory.address,
//       globalState.address,
//     ]);

//     // OrderBook
//     const orderBook = await deployContract(
//       "OrderBook",
//       [
//         traderVault.address,
//         risePool.address,
//         market.address,
//         positionHistory.address,
//         positionVault.address,
//       ],
//       mathUtils.address
//     );

//     // OrderRouter
//     const orderRouter = await deployContract("OrderRouter", [
//       marketOrder.address,
//       orderBook.address,
//     ]);

//     return [[deployer, trader, priceKeeper],[positionFee,priceManager, orderRouter]];
//   }

// describe("Open Fee Test", function () {
//   const USD_ID = 0;
//   const ETH_ID = 1;

//   const USD_DECIMALS = 20;
//   const ETH_DECIMALS = 18;
//   const PRICE_BUFFER_DECIMALS = 8;

//   it("Should get right position fee", async function () {
//     const [[deployer, trader, priceKeeper],[positionFee,priceManager, orderRouter]] = await deployContracts();

//     let result = await positionFee.getPositionFee(fromUSD(100),0)
//     console.log(toUSD(result))

//   });
//   it("Should pay right position fee", async function () {
//     const [[deployer, trader, priceKeeper],[positionFee,priceManager, orderRouter]] = await deployContracts();

//     let result = await positionFee.getPositionFee(fromUSD(100),0)
//     console.log(toUSD(result))

//   });

// })
