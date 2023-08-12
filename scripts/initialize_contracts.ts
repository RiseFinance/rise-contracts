import { getContract, Network } from "../utils/getContract";
import { getContractAddress } from "../utils/getContractAddress";

export async function initialize() {
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
  const tokenInfo = getContract("market", "TokenInfo", Network.L3);

  // initialization parameters
  const l3GatewayAddress = getContractAddress("L3Gateway");
  const testUsdcAddress = getContractAddress("TestUSDC");

  await l2MarginGateway.initialize(l3GatewayAddress);
  await l2LiquidityGateway.initialize(l3GatewayAddress);
  await tokenInfo.registerToken(testUsdcAddress, 18);

  console.log("Contracts initialized");
}

async function main() {
  await initialize();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
