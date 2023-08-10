import { deployContract } from "../utils/deployer";

export async function deployL2Contracts() {
  // Nitro Contracts
  const _inbox = "0x0A0dD8845C0064f03728F7f145B7DDA05FD0Ccc6";

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
  console.log(">>> L2 Contracts Deployed.");
  console.log(">>> test USDC: ", usdc.address);
  console.log(">>> Market: ", market.address);
  console.log(">>> TokenInfo: ", tokenInfo.address);
  console.log(">>> L2Vault: ", l2Vault.address);
  console.log(">>> L2MarginGateway: ", l2MarginGateway.address);
  console.log(">>> RisePoolUtils: ", risePoolUtils.address);
  console.log(">>> L2LiquidityGateway: ", l2LiquidityGateway.address);
  console.log("---------------------------------------------");
}
