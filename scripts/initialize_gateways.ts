import { ethers } from "hardhat";
import { getContract } from "../utils/getContract";

export async function initialize() {
  const privateKey = process.env.DEPLOY_PRIVATE_KEY as string;

  const l2Provider = new ethers.providers.JsonRpcProvider(
    "https://goerli-rollup.arbitrum.io/rpc"
  );

  const l2Wallet = new ethers.Wallet(privateKey, l2Provider);

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
