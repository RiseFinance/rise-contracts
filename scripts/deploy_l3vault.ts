import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // ==================== Set Contract Factory & Constructor ====================
  const PriceFeedContract = await ethers.getContractFactory("PriceFeed");
  const L3VaultContract = await ethers.getContractFactory("L3Vault");
  console.log(">>> got contract factories");

  // ==================== Deploy Contracts ====================
  const priceFeedContract = await PriceFeedContract.deploy();
  console.log(">>> PriceFeed Deployment in progress...");
  await priceFeedContract.deployed();
  console.log(`Deployed PriceFeed Contract: ${priceFeedContract.address}`);

  const l3VaultContract = await L3VaultContract.deploy(
    priceFeedContract.address
  );
  console.log("\n>>> L3Vault Deployment in progress...");
  await l3VaultContract.deployed();
  console.log(`Deployed L3Vault Contract: ${l3VaultContract.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.a
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
