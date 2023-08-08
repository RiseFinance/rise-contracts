import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // ==================== Set Contract Factory & Constructor ====================
  const L2VaultContract = await ethers.getContractFactory("L2Vault");
  console.log(">>> got contract factories");

  // ==================== Deploy Contracts ====================

  const l2VaultContract = await L2VaultContract.deploy();
  console.log("\n>>> L2Vault Deployment in progress...");
  await l2VaultContract.deployed();
  console.log(`Deployed L2Vault Contract: ${l2VaultContract.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.a
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
