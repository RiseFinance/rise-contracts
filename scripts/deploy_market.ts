import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // ==================== Set Contract Factory & Constructor ====================
  const MarketContract = await ethers.getContractFactory("Market");
  console.log(">>> got contract factories");

  // ==================== Deploy Contracts ====================

  const marketContract = await MarketContract.deploy();
  console.log("\n>>> Market Deployment in progress...");
  await marketContract.deployed();
  console.log(`Deployed Market Contract: ${marketContract.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.a
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
