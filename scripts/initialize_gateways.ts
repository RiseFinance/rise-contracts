import { ethers } from "hardhat";
import { getContract } from "../utils/getContract";

async function main() {
  const privateKey = process.env.DEPLOY_PRIVATE_KEY as string;

  const l2Provider = new ethers.providers.JsonRpcProvider(
    "https://goerli-rollup.arbitrum.io/rpc"
  );
  // const l3Provider = new ethers.providers.JsonRpcProvider(
  //   "http://localhost:8449"
  // );
  const l2Wallet = new ethers.Wallet(privateKey, l2Provider);
  // const l3Wallet = new ethers.Wallet(privateKey, l3Provider);

  const l2MarginGateway = await getContract("L2MarginGateway", "", l2Wallet);
  const l2LiquidityGateway = await getContract(
    "L2LiquidityGateway",
    "",
    l2Wallet
  );

  const _l3GatewayAddress = "";

  l2MarginGateway.initialize(_l3GatewayAddress);
  l2LiquidityGateway.initialize(_l3GatewayAddress);
}

// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
