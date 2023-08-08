import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // ==================== Set Contract Factory & Constructor ====================
  const TokenInfoContract = await ethers.getContractFactory("TokenInfo");
  console.log(">>> got contract factories");

  // ==================== Deploy Contracts ====================

  const _marketAddress = "0xC78D420557C42467a760A8792739BF982c9144B5";
  const tokenInfoContract = await TokenInfoContract.deploy(_marketAddress);
  console.log("\n>>> TokenInfo Deployment in progress...");
  await tokenInfoContract.deployed();
  console.log(`Deployed TokenInfo Contract: ${tokenInfoContract.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.a
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
