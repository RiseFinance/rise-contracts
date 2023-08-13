import { getContract, Network } from "../utils/getContract";
import { getContractAddress } from "../utils/getContractAddress";
import { getPresetAddress } from "../utils/getPresetAddress";

export async function initialize() {
  const l2Vault = getContract("crosschain", "L2Vault", Network.L2);

  const l2MarginGateway = getContract(
    "crosschain",
    "L2MarginGateway",
    Network.L2
  );
  const l2LiquidityGateway = getContract(
    "crosschain",
    "L2LiquidityGateway",
    Network.L2
  );
  const tokenInfoL2 = getContract("market", "TokenInfo", Network.L2);
  const tokenInfoL3 = getContract("market", "TokenInfo", Network.L3);

  // initialization parameters

  const l3GatewayAddress = getContractAddress("L3Gateway");
  const testUsdcAddress = getContractAddress("TestUSDC");
  const bridgeAddress = getPresetAddress("Bridge");

  await l2MarginGateway.initialize(l3GatewayAddress);
  await l2MarginGateway.setAllowedBridge(bridgeAddress);
  console.log(">>> L2MarginGateway initialized");

  await l2LiquidityGateway.initialize(l3GatewayAddress);
  await l2LiquidityGateway.setAllowedBridge(bridgeAddress);
  console.log(">>> L2LiquidityGateway initialized");

  await l2Vault.setAllowedGateway(l2MarginGateway.address);
  await l2Vault.setAllowedGateway(l2LiquidityGateway.address);
  console.log(">>> L2Vault initialized");

  await tokenInfoL2.registerToken(testUsdcAddress, 18);
  await tokenInfoL3.registerToken(testUsdcAddress, 18);
  console.log(">>> TokenInfo initialized");

  console.log("Contracts initialized");
}

async function main() {
  await initialize();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
