import * as fs from "fs";
import { deployContract } from "../utils/deployer";

export type L2Addresses = {
  USDC: string;
  Market: string;
  TokenInfo: string;
  L2Vault: string;
  L2MarginGateway: string;
  RisePoolUtils: string;
  L2LiquidityGateway: string;
};

export async function deployL2Contracts(_inbox: string): Promise<L2Addresses> {
  // test USDC
  const usdc = await deployContract("USDC");

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
  console.log("test USDC: ", usdc.address);
  console.log("Market: ", market.address);
  console.log("TokenInfo: ", tokenInfo.address);
  console.log("L2Vault: ", l2Vault.address);
  console.log("L2MarginGateway: ", l2MarginGateway.address);
  console.log("RisePoolUtils: ", risePoolUtils.address);
  console.log("L2LiquidityGateway: ", l2LiquidityGateway.address);
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
    fs.readFileSync(__dirname + "/output/Addresses.json").toString()
  )["Library"];

  fs.writeFileSync(
    __dirname + "/output/Addresses.json",
    JSON.stringify({ Library: libraryAddresses, L2: l2Addresses }, null, 2),
    { flag: "w" }
  );

  return l2Addresses;
}
