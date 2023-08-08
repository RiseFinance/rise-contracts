import { ethers } from "hardhat";

async function main() {
  console.log(">>> deploying test USDC to L2 network...");
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // ==================== Set Contract Factory & Constructor ====================
  const UsdcContract = await ethers.getContractFactory("USDC");
  console.log(">>> got contract factory");

  // ==================== Deploy Contracts ====================
  const usdcContract = await UsdcContract.deploy();
  console.log(">>> UsdcContract Deployment in progress...");
  await usdcContract.deployed();
  console.log(`Deployed USDC Contract: ${usdcContract.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
