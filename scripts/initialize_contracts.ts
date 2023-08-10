import { ethers } from "hardhat";
import { getContract } from "../utils/getContract";

export async function initialize(
  _l2MarginGateway: string,
  _l2LiquidityGateway: string,
  _l3Gateway: string,
  _priceManager: string,
  _orderBook: string
) {
  const privateKey = process.env.DEPLOY_PRIVATE_KEY as string;

  const l2Provider = new ethers.providers.JsonRpcProvider(
    "https://goerli-rollup.arbitrum.io/rpc"
  );

  const l3Provider = new ethers.providers.JsonRpcProvider(
    "http://localhost:8449"
  );

  const l2Wallet = new ethers.Wallet(privateKey, l2Provider);
  const l3Wallet = new ethers.Wallet(privateKey, l3Provider);

  const l2MarginGateway = await getContract(
    "crosschain",
    "L2MarginGateway",
    _l2MarginGateway,
    l2Wallet
  );
  const l2LiquidityGateway = await getContract(
    "crosschain",
    "L2LiquidityGateway",
    _l2LiquidityGateway,
    l2Wallet
  );
  const priceManager = await getContract(
    "oracle",
    "PriceManager",
    _priceManager,
    l3Wallet
  );

  l2MarginGateway.initialize(_l3Gateway);
  l2LiquidityGateway.initialize(_l3Gateway);
  priceManager.initialize(_orderBook);
}
