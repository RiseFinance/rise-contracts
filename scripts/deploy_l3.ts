import { ethers } from "hardhat";
import { deployContract } from "../utils/contract-deployer";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  await deployL3Contracts();
}

// L3 Contracts

async function deployL3Contracts() {
  // TraderVault
  const TraderVault = await ethers.getContractFactory("TraderVault");
  const traderVault = await TraderVault.deploy();
  console.log(">>> TraderVault Deployment in progress...");
  await traderVault.deployed();
  console.log(">>> TraderVault Deployed.");

  // Market
  const Market = await ethers.getContractFactory("Market");
  const market = await Market.deploy();
  console.log(">>> Market Deployment in progress...");
  await market.deployed();
  console.log(">>> Market Deployed.");

  // TokenInfo
  const TokenInfo = await ethers.getContractFactory("TokenInfo");
  const tokenInfo = await TokenInfo.deploy(market.address);
  console.log(">>> TokenInfo Deployment in progress...");
  await tokenInfo.deployed();
  console.log(">>> TokenInfo Deployed.");

  // RisePool
  await deployContract("RisePool");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
