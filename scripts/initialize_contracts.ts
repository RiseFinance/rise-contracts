import { getContract, Network } from "../utils/getContract";
import { getContractAddress } from "../utils/getContractAddress";

export async function initialize() {
  const l2MarginGateway = await getContract(
    "crosschain",
    "L2MarginGateway",
    Network.L2
  );
  const l2LiquidityGateway = await getContract(
    "crosschain",
    "L2LiquidityGateway",
    Network.L2
  );

  // initialization parameters
  const l3GatewayAddress = getContractAddress("L3Gateway");

  l2MarginGateway.initialize(l3GatewayAddress);
  l2LiquidityGateway.initialize(l3GatewayAddress);
}

async function main() {
  await initialize();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
