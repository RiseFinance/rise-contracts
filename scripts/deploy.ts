import { ethers } from "hardhat";

import { deployL2Contracts } from "./deploy_l2";
import { deployL3Contracts } from "./deploy_l3";
import { initialize } from "./initialize_gateways";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  await deployL2Contracts();
  await deployL3Contracts();
  await initialize();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
