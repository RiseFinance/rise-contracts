import { ethers } from "hardhat";
import * as fs from "fs";

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

  const mathUtils = await deployLibraries();
  const l2Addresses = await deployL2Contracts(_inbox);
  const l3Addresses = await deployL3Contracts(
    mathUtils.address,
    l2Addresses.L2MarginGateway,
    l2Addresses.L2LiquidityGateway,
    _keeper
  );

  const addresses = {
    L2: l2Addresses,
    L3: l3Addresses,
  };

  // deployed contract addresses
  fs.writeFileSync(
    __dirname + "/output/Addresses.json",
    JSON.stringify(addresses, null, 2)
  );

  // not for local test
  await initialize(
    l2Addresses.L2MarginGateway,
    l2Addresses.L2LiquidityGateway,
    l3Addresses.L3Gateway,
    l3Addresses.PriceManager,
    l3Addresses.OrderBook
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
