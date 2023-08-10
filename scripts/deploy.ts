import { ethers } from "hardhat";
import * as fs from "fs";

import { getContractAddress } from "../utils/getContractAddress";
import { deployLibraries } from "./deploy_libraries";
import { deployL2Contracts } from "./deploy_l2";
import { deployL3Contracts } from "./deploy_l3";
import { initialize } from "./initialize_contracts";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log(
    "Account balance:",
    ethers.utils.formatEther((await deployer.getBalance()).toString()),
    "ETH"
  );
  console.log("---------------------------------------------");

  const _inbox = "0x0A0dD8845C0064f03728F7f145B7DDA05FD0Ccc6";
  const _keeper = "0xDe264e2133963c9f40e07f290E1D852f7e4e4c7c";

  await deployLibraries();

  const mathUtils = await getContractAddress("MathUtils");

  await deployL2Contracts(_inbox);

  const l2MarginGateway = await getContractAddress("L2MarginGateway");
  const l2LiquidityGateway = await getContractAddress("L2LiquidityGateway");

  await deployL3Contracts(
    mathUtils,
    l2MarginGateway,
    l2LiquidityGateway,
    _keeper
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
