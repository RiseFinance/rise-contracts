import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("L3Vault", function () {
  async function deployL3VaultFixture() {
    const [deployer] = await ethers.getSigners();
    const L3Vault = await ethers.getContractFactory("L3Vault");
    const l3Vault = await L3Vault.deploy();
    return { l3Vault, deployer };
  }

  describe("Deployment", function () {
    it("Should be deployed", async function () {
      // TODO: add implementation after adding the constructor
    });
  });

  describe("Liquidity Pool", function () {
    it("Should be able to add liquidity", async function () {
      const { l3Vault } = await loadFixture(deployL3VaultFixture);
      const _assetId = 1;
      const _amount = 1000;

      expect(await l3Vault.tokenPoolAmounts(_assetId)).to.equal(0);
      await l3Vault.addLiquidity(_assetId, _amount);
      expect(await l3Vault.tokenPoolAmounts(_assetId)).to.equal(_amount);
    });
  });

  describe("Open Position", function () {
    it("Should be able to open a long position", async function () {
      const { l3Vault, deployer } = await loadFixture(deployL3VaultFixture);

      const _account = await deployer.getAddress();
      const _collateralAssetId = 1; // ETH
      const _indexAssetId = 1; // ETH
      const _size = 225; // 225 ETH
      const _collateralSize = 45; // 45 ETH, x5 leverage
      const _isLong = true;

      expect(
        await l3Vault.openPosition(
          _account,
          _collateralAssetId,
          _indexAssetId,
          _size,
          _collateralSize,
          _isLong
        )
      ).not.to.be.reverted;
    });
  });
});
