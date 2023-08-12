import * as fs from "fs";
import { deployContract } from "../utils/deployer";
import { getPresetAddress } from "../utils/getPresetAddress";

export type L2Addresses = {
  USDC: string;
  Market: string;
  TokenInfo: string;
  L2Vault: string;
  L2MarginGateway: string;
  RisePoolUtils: string;
  L2LiquidityGateway: string;
};

async function main() {
  await deployL2Contracts();
}

async function deployL2Contracts(): Promise<L2Addresses> {
  const _inbox = await getPresetAddress("inbox");

  // test USDC
  const usdc = await deployContract("TestUSDC");

  // Market
  const market = await deployContract("Market");

  // TokenInfo
  const tokenInfo = await deployContract("TokenInfo", [market.address]);

  // L2Vault
  const l2Vault = await deployContract("L2Vault");

  //L2MarginGateway
  const l2MarginGateway = await deployContract("L2MarginGateway", [
    _inbox,
    l2Vault.address,
    tokenInfo.address,
  ]);

  // RisePoolUtils
  const risePoolUtils = await deployContract("RisePoolUtils");

  //L2LiquidityGateway
  const l2LiquidityGateway = await deployContract("L2LiquidityGateway", [
    _inbox,
    l2Vault.address,
    market.address,
    risePoolUtils.address,
  ]);
  console.log(">>> L2LiquidityGateway Deployed.");

  console.log("---------------------------------------------");
  console.log(">>> L2 Contracts Deployed:");
  console.log("Test USDC:", usdc.address);
  console.log("Market:", market.address);
  console.log("TokenInfo:", tokenInfo.address);
  console.log("L2Vault:", l2Vault.address);
  console.log("L2MarginGateway:", l2MarginGateway.address);
  console.log("RisePoolUtils:", risePoolUtils.address);
  console.log("L2LiquidityGateway:", l2LiquidityGateway.address);
  console.log("---------------------------------------------");

  const l2Addresses = {
    USDC: usdc.address,
    Market: market.address,
    TokenInfo: tokenInfo.address,
    L2Vault: l2Vault.address,
    L2MarginGateway: l2MarginGateway.address,
    RisePoolUtils: risePoolUtils.address,
    L2LiquidityGateway: l2LiquidityGateway.address,
  };

  const libraryAddresses = JSON.parse(
    fs.readFileSync(__dirname + "/output/contractAddresses.json").toString()
  )["Library"];

  fs.writeFileSync(
    __dirname + "/output/contractAddresses.json",
    JSON.stringify({ Library: libraryAddresses, L2: l2Addresses }, null, 2),
    { flag: "w" }
  );

  return l2Addresses;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
