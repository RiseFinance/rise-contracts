import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // ==================== Set Contract Factory & Constructor ====================

  const Contract = await ethers.getContractFactory("L3Vault");
  console.log(">>> got contract factory");
  const contract = await Contract.deploy();
  // ============================================================================
  console.log(">>> Deployment in progress...");
  await contract.deployed();
  console.log(`Deployed Contract: ${contract.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.a
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
