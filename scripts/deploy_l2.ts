import fs from "fs";
import { deployContract } from "../utils/deployer";

export async function deployL2Contracts(_inbox: string) {
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

  const l2Contracts = {
    usdc: usdc.address,
    market: market.address,
    tokenInfo: tokenInfo.address,
    l2Vault: l2Vault.address,
    l2MarginGateway: l2MarginGateway.address,
    risePoolUtils: risePoolUtils.address,
    l2LiquidityGateway: l2LiquidityGateway.address,
  };

  fs.writeFileSync(
    __dirname + "/output/l2Contracts.json",
    JSON.stringify(l2Contracts, null, 2)
  );

  return [l2MarginGateway, l2LiquidityGateway];
}
