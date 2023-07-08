import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("L3Vault", function () {
  async function deployL3VaultFixture() {
    const [deployer, lp, trader] = await ethers.getSigners();
    const PriceFeed = await ethers.getContractFactory("PriceFeed");
    const priceFeed = await PriceFeed.deploy();
    const L3Vault = await ethers.getContractFactory("L3Vault");
    const l3Vault = await L3Vault.deploy(priceFeed.address);
    const ETH_ID = 1;
    return { l3Vault, priceFeed, deployer, lp, trader, ETH_ID };
  }

  describe("Deployment", function () {
    it("Should be deployed with PriceFeed contract address", async function () {
      const { l3Vault, priceFeed } = await loadFixture(deployL3VaultFixture);
      expect(await l3Vault.priceFeed()).to.equal(priceFeed.address);
    });
  });

  describe("Liquidity Pool", function () {
    it("Should be able to add liquidity", async function () {
      const { l3Vault, lp, ETH_ID } = await loadFixture(deployL3VaultFixture);
      const _assetId = ETH_ID;
      const _amount = ethers.utils.parseEther("100");

      expect(await l3Vault.tokenPoolAmounts(_assetId)).to.equal(0);
      await l3Vault
        .connect(lp)
        .addLiquidity(_assetId, _amount, { value: _amount });
      expect(await l3Vault.tokenPoolAmounts(_assetId)).to.equal(_amount);
    });
  });

  describe("Integration Test", function () {
    // flow: add liquidity => deposit ETH => set price (PriceFeed) => open position
    it("Should be able to open then close a long position", async function () {
      const isLong = true;
      const { l3Vault, priceFeed, deployer, lp, trader, ETH_ID } =
        await loadFixture(deployL3VaultFixture);

      // 1. add liquidity (lp)
      const _amount = ethers.utils.parseEther("1000");
      await l3Vault
        .connect(lp)
        .addLiquidity(ETH_ID, _amount, { value: _amount });
      expect(await l3Vault.tokenPoolAmounts(ETH_ID)).to.equal(_amount);
      console.log(
        ">>> LP added liquidity: ",
        ethers.utils.formatEther(_amount),
        " ETH"
      );

      // 2. deposit 90 ETH (trader)
      const _value = ethers.utils.parseEther("90");
      await l3Vault.connect(trader).depositEth({ value: _value });
      const _traderAddress = await trader.getAddress();
      expect(
        (await l3Vault.traderBalances(_traderAddress, ETH_ID)).balance
      ).to.equal(_value);
      console.log(
        ">>> Trader deposited: ",
        ethers.utils.formatEther(_value),
        " ETH"
      );

      // inspect state variables before opening the position
      // traderBalances, tokenPoolAmounts, tokenReserveAmounts, positions

      console.log("\n\n---------- Before opening the position ----------");
      console.log(
        ">>> trader ETH balance: ",
        ethers.utils.formatEther(
          (await l3Vault.traderBalances(_traderAddress, ETH_ID)).balance
        ),
        " ETH"
      );
      console.log(
        ">>> ETH pool amounts: ",
        ethers.utils.formatEther(await l3Vault.tokenPoolAmounts(ETH_ID)),
        "ETH"
      );
      console.log(
        ">>> ETH reserve amounts: ",
        ethers.utils.formatEther(await l3Vault.tokenReserveAmounts(ETH_ID)),
        "ETH"
      );

      // check globalLongState
      const glsBeforeOpenOrder = await l3Vault.globalPositionState(isLong);
      console.log(
        "\n>>> globalLongState: totalSize =",
        ethers.utils.formatEther(glsBeforeOpenOrder.totalSize),
        "ETH",
        "totalCollateral =",
        ethers.utils.formatEther(glsBeforeOpenOrder.totalCollateral),
        "ETH",
        "averagePrice =",
        ethers.utils.formatUnits(glsBeforeOpenOrder.averagePrice, 8),
        "USD/ETH\n"
      );

      console.log(
        ">>> trader's order count: [",
        (
          await l3Vault.traderBalances(_traderAddress, ETH_ID)
        ).orderCount.toString(),
        "]"
      );

      // 3. set price (PriceFeed) (deployer)
      const _price = ethers.utils.parseUnits("1923.56", 8);
      await priceFeed.setPrice(ETH_ID, _price);
      expect(await priceFeed.getPrice(ETH_ID)).to.equal(_price);

      // 4. open position (trader)
      const _account = await trader.getAddress();
      const _collateralAssetId = ETH_ID; // ETH
      const _indexAssetId = ETH_ID; // ETH
      const _size = ethers.utils.parseEther("225"); // 225 ETH
      const _collateralSize = ethers.utils.parseEther("45"); // 45 ETH, x5 leverage
      const _isLong = true;
      const _isMarketOrder = true;

      const _positionKey = await l3Vault
        .connect(trader)
        .callStatic.openPosition(
          _account,
          _collateralAssetId,
          _indexAssetId,
          _size,
          _collateralSize,
          _isLong,
          _isMarketOrder
        );

      expect(
        await l3Vault
          .connect(trader)
          .openPosition(
            _account,
            _collateralAssetId,
            _indexAssetId,
            _size,
            _collateralSize,
            _isLong,
            _isMarketOrder
          )
      ).not.to.be.reverted;

      // 5. check position
      const position = await l3Vault.getPosition(_positionKey);
      expect(position.size).to.equal(_size);
      expect(position.collateralSize).to.equal(_collateralSize);
      expect(position.avgOpenPrice).to.equal(_price);
      console.log("\n\n---------- After opening the position ----------");
      console.log(
        ">>> trader ETH balance: ",
        ethers.utils.formatEther(
          (await l3Vault.traderBalances(_traderAddress, ETH_ID)).balance
        ),
        " ETH"
      );
      console.log(
        ">>> ETH pool amounts: ",
        ethers.utils.formatEther(await l3Vault.tokenPoolAmounts(ETH_ID)),
        "ETH"
      );
      console.log(
        ">>> ETH reserve amounts: ",
        ethers.utils.formatEther(await l3Vault.tokenReserveAmounts(ETH_ID)),
        "ETH"
      );

      // check globalLongState
      const glsAfterOpenOrder = await l3Vault.globalPositionState(isLong);
      console.log(
        "\n>>> globalLongState: totalSize =",
        ethers.utils.formatEther(glsAfterOpenOrder.totalSize),
        "ETH",
        "totalCollateral =",
        ethers.utils.formatEther(glsAfterOpenOrder.totalCollateral),
        "ETH",
        "averagePrice =",
        ethers.utils.formatUnits(glsAfterOpenOrder.averagePrice, 8),
        "USD/ETH\n"
      );

      const orderCountAfterOpeningPosition = (
        await l3Vault.traderBalances(_traderAddress, ETH_ID)
      ).orderCount.toString();
      console.log(
        ">>> trader's order count: [",
        orderCountAfterOpeningPosition,
        "]"
      );

      const openPositionOrder = await l3Vault.traderOrders(
        _traderAddress,
        +orderCountAfterOpeningPosition - 1
      );
      console.log("\n>>> Order #1: Open position order placed");
      console.log(">>> isLong: ", openPositionOrder.isLong);
      console.log(">>> isMarketOrder: ", openPositionOrder.isMarketOrder);
      console.log(
        ">>> sizeDeltaAbs: ",
        ethers.utils.formatEther(openPositionOrder.sizeDeltaAbs),
        " ETH"
      );
      console.log(
        ">>> markPrice: ",
        ethers.utils.formatUnits(openPositionOrder.markPrice, 8),
        " USD/ETH"
      );
      console.log(">>> indexAssetId: ", openPositionOrder.indexAssetId);
      console.log(
        ">>> collateralAssetId: ",
        openPositionOrder.collateralAssetId
      );
      console.log("\n");

      // 6. close position
      // update mark price
      //   const _priceDeltaRatioInPercent = -5; // 5% decrease
      //   const _newPrice = _price.mul(100 + _priceDeltaRatioInPercent).div(100);
      const _newPrice = ethers.utils.parseUnits("1909.19", 8);
      await priceFeed.setPrice(ETH_ID, _newPrice);
      expect(await priceFeed.getPrice(ETH_ID)).to.equal(_newPrice);

      expect(
        await l3Vault
          .connect(trader)
          .closePosition(
            _account,
            _collateralAssetId,
            _indexAssetId,
            _isLong,
            _isMarketOrder
          ) // => open position할 때의 값을 재활용
      ).not.to.be.reverted;

      console.log("\n\n---------- After closing the position ----------");
      console.log(
        ">>> trader ETH balance: ",
        ethers.utils.formatEther(
          (await l3Vault.traderBalances(_traderAddress, ETH_ID)).balance
        ),
        "ETH"
      );
      console.log(
        ">>>ETH pool amounts: ",
        ethers.utils.formatEther(await l3Vault.tokenPoolAmounts(ETH_ID)),
        "ETH"
      );
      console.log(
        ">>>ETH reserve amounts: ",
        ethers.utils.formatEther(await l3Vault.tokenReserveAmounts(ETH_ID)),
        "ETH"
      );

      // check globalLongState
      const glsAfterCloseOrder = await l3Vault.globalPositionState(isLong);
      console.log(
        "\n>>> globalLongState: totalSize =",
        ethers.utils.formatEther(glsAfterCloseOrder.totalSize),
        "ETH",
        "totalCollateral =",
        ethers.utils.formatEther(glsAfterCloseOrder.totalCollateral),
        "ETH",
        "averagePrice =",
        ethers.utils.formatUnits(glsAfterCloseOrder.averagePrice, 8),
        "USD/ETH\n"
      );

      const orderCountAfterClosingPosition = (
        await l3Vault.traderBalances(_traderAddress, ETH_ID)
      ).orderCount.toString();
      console.log(
        ">>> trader's order count: [",
        +orderCountAfterClosingPosition - 1,
        "]"
      );

      const closePositionOrder = await l3Vault.traderOrders(
        _traderAddress,
        +orderCountAfterClosingPosition - 1
      );
      console.log("\n>>> Order #2: Close position order placed");
      console.log(">>> isLong: ", closePositionOrder.isLong);
      console.log(">>> isMarketOrder: ", closePositionOrder.isMarketOrder);
      console.log(
        ">>> sizeDeltaAbs: ",
        ethers.utils.formatEther(closePositionOrder.sizeDeltaAbs),
        " ETH"
      );
      console.log(
        ">>> markPrice: ",
        ethers.utils.formatUnits(closePositionOrder.markPrice, 8),
        " USD/ETH"
      );
      console.log(">>> indexAssetId: ", closePositionOrder.indexAssetId);
      console.log(
        ">>> collateralAssetId: ",
        closePositionOrder.collateralAssetId
      );
      console.log("\n");
      //   console.log(">>> position: ", await l3Vault.getPosition(_positionKey));

      // 7. withdraw ETH

      const _withdrawAmount = (
        await l3Vault.traderBalances(_traderAddress, ETH_ID)
      ).balance; // withdraw all

      await l3Vault.connect(trader).withdrawEth(_withdrawAmount);
      console.log(">>> withdraw complete.");

      console.log(
        ">>> trader ETH balance: ",
        ethers.utils.formatEther(
          (await l3Vault.traderBalances(_traderAddress, ETH_ID)).balance
        ),
        " ETH"
      );
      console.log(
        ">>> ETH pool amounts: ",
        ethers.utils.formatEther(await l3Vault.tokenPoolAmounts(ETH_ID)),
        "ETH"
      );
      console.log(
        ">>> ETH reserve amounts: ",
        ethers.utils.formatEther(await l3Vault.tokenReserveAmounts(ETH_ID)),
        "ETH"
      );

      // 8. remove liquidity
      // TODO: lp가 얼마만큼의 liquidity를 뺄 수 있는지 트래킹할 수 있는 방법이 필요함

      const _removeLiquidityAmount = await l3Vault.tokenPoolAmounts(ETH_ID); // all
      await l3Vault.connect(lp).removeLiquidity(ETH_ID, _removeLiquidityAmount);
      console.log(">>> liquidity removed");

      console.log("\n\n---------- After removing liquidity ----------");
      console.log(
        ">>> ETH pool amounts: ",
        ethers.utils.formatEther(await l3Vault.tokenPoolAmounts(ETH_ID)),
        "ETH"
      );
      console.log(
        ">>> ETH reserve amounts: ",
        ethers.utils.formatEther(await l3Vault.tokenReserveAmounts(ETH_ID)),
        "ETH"
      );
    });
  });
});
