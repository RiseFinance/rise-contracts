import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
/**
 * struct OrderContext {
    bool _isLong;
    bool _isIncrease;
    uint256 _indexAssetId;
    uint256 _collateralAssetId;
    uint256 _sizeAbsInUsd;
    uint256 _collateralAbsInUsd;
    uint256 _limitPrice; // empty for market orders
}
*/

describe("Place Limit Order", function() {

    const USD_ID = 0;
    const ETH_ID = 1;

    const USD_DECIMALS = 20;
    const ETH_DECIMALS = 18;
    const PRICE_BUFFER_DECIMALS = 8;

    // Fixtures
    async function deployContracts() {
        const [deployer, trader, priceKeeper] = await ethers.getSigners();
        const l3Vault = await (await ethers.getContractFactory("L3Vault")).deploy();
        const orderBook = await (await ethers.getContractFactory("OrderBook")).deploy(l3Vault.address);
        const priceManager = await (await ethers.getContractFactory("PriceManager")).deploy(orderBook.address, priceKeeper.address);
        const orderRouter = await (await ethers.getContractFactory("OrderRouter")).deploy(l3Vault.address, orderBook.address, priceManager.address);

        return { deployer, trader, l3Vault, orderBook, priceManager, orderRouter };
    }

    async function configureL3Vault(l3Vault: any) {
        await l3Vault.setAssetIdCounter(2); // ETH, USD
    }

    async function depositToTraderAccount(l3Vault: any, trader: any) {
        const depositAmount = ethers.utils.parseUnits("5000", USD_DECIMALS); // 5000 USD
        await l3Vault.connect(trader).increaseTraderBalance(trader.address, USD_ID, depositAmount);
    }

    async function checkTraderAccountBalance() {
    }

    // this.beforeEach(async () => {});
    // this.afterEach(async () => {});

    // TODO: configure different orderbook states

    it("Should place a limit order (ETH/USD x8 Long Increase)", async function(){
        const { deployer, trader, l3Vault, orderBook, priceManager, orderRouter } = await loadFixture(deployContracts);
        await configureL3Vault(l3Vault);
        await depositToTraderAccount(l3Vault, trader);

        const orderContext = {
            _isLong: true,
            _isIncrease: true,
            _indexAssetId: ETH_ID,
            _collateralAssetId: USD_ID,
            _sizeAbsInUsd: ethers.utils.parseUnits("16000", USD_DECIMALS),
            _collateralAbsInUsd: ethers.utils.parseUnits("2000", USD_DECIMALS), // x8 leverage
            _limitPrice: 1950
        };

        await orderRouter.connect(trader).placeLimitOrder(orderContext);

        const orderRequest = await orderBook.buyOrderBook(ETH_ID, 1950, 1); // orderbook reader 필요?
        // 존재하는지부터 확인 필요
        expect(orderRequest.trader).to.equal(trader.address);
        expect(orderRequest.isLong).to.equal(true);
        expect(orderRequest.isIncrease).to.equal(true);
        expect(orderRequest.indexAssetId).to.equal(ETH_ID);
        expect(orderRequest.collateralAssetId).to.equal(USD_ID);
        expect(orderRequest.sizeAbsInUsd).to.equal(ethers.utils.parseUnits("16000", USD_DECIMALS));
        expect(orderRequest.collateralAbsInUsd).to.equal(ethers.utils.parseUnits("2000", USD_DECIMALS));
        expect(orderRequest.limitPrice).to.equal(1950);     
    });


});
