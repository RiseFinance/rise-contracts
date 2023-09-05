import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployContract } from "../utils/deployer";
describe("Test Price buffer effect", function () {

    const USD_ID = 0;
    const ETH_ID = 1;

    const USD_DECIMALS = 20;
    const ETH_DECIMALS = 18;
    const PRICE_BUFFER_DECIMALS = 8;    

    async function deployContracts(
        ) {
          const [deployer, trader, priceKeeper] =  await ethers.getSigners();
        const mathUtils = await deployContract("MathUtils");
          // TraderVault
          const traderVault = await deployContract("TraderVault");
          // Market
          const market = await deployContract("Market");
          // TokenInfo
          const tokenInfo = await deployContract("TokenInfo", [market.address]);
          // RisePool
          const risePool = await deployContract("RisePool");
          // GlobalState
          const globalState = await deployContract("GlobalState", [], mathUtils.address);
          // PriceManager
          const priceManager = await deployContract("PriceManager", [
            globalState.address,
            tokenInfo.address,
            priceKeeper.address, // _keeperAddress
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
            mathUtils.address
          );
          // PositionVault
          const positionVault = await deployContract(
            "PositionVault",
            [funding.address],
            mathUtils.address
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
            mathUtils.address
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
            mathUtils.address
          );
          // OrderRouter
          const orderRouter = await deployContract("OrderRouter", [
            marketOrder.address,
            orderBook.address,
          ]);
          return [[deployer, trader, priceKeeper],[traderVault, orderRouter, priceManager,orderBook]];
        }
    
    async function depositToTraderAccount(traderVault: any, trader: any) {
    const depositAmount = ethers.utils.parseUnits("5000", USD_DECIMALS); // 5000 USD
    await traderVault
      .connect(trader)
      .increaseTraderBalance(trader.address, USD_ID, depositAmount);
  }
  
  it("Should do blah ", async function () {
        const [signers, contracts] = await loadFixture(deployContracts);
        const [deployer, trader, priceKeeper] = signers;
        const [tradervault, orderRouter, priceManager,orderBook] = contracts;
        await depositToTraderAccount(tradervault, trader);
        const depositAmount = ethers.utils.parseUnits("5000", USD_DECIMALS); // 5000 USD
        expect(await tradervault.getTraderBalance(trader.address, USD_ID)).to.equal(depositAmount);



    });
/*
    it("Should manage price update ", async function () {
      const [signers, contracts] = await loadFixture(deployContracts);
      const [deployer, trader, priceKeeper] = signers;
      const [tradervault, orderRouter, priceManager,orderBook] = contracts;
      //await priceManager.initialize(orderBook.address);
      await priceManager.isPriceKeeper[priceKeeper.address] = true ;
      await priceManager.connect(priceKeeper).setPrice([ETH_ID], [1000], true);
      //await priceManager.setPrice([ETH_ID], [3000], true);
      expect (await priceManager.indexPrices[ETH_ID]).to.equal(1000);
      //await priceManager.setPrice([ETH_ID], [4000], true);
      //expect (await priceManager.indexPrices(ETH_ID)).to.equal(4000);
    });

*/
});
