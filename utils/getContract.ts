import { ethers } from "ethers";
import * as path from "path";
import * as fs from "fs";
import { getContractAddress } from "./getContractAddress";

export enum Network {
  L2 = "l2",
  L3 = "l3",
}

export function getContract(
  domainName: string,
  contractName: string,
  network: Network
) {
  const privateKey = process.env.DEPLOY_PRIVATE_KEY as string;

  let provider;

  if (network === Network.L2) {
    provider = new ethers.providers.JsonRpcProvider(
      "https://goerli-rollup.arbitrum.io/rpc"
    );
  } else if (network === Network.L3) {
    provider = new ethers.providers.JsonRpcProvider("http://localhost:8449");
  } else {
    throw new Error("Invalid network");
  }

  const wallet = new ethers.Wallet(privateKey, provider);

  const contractAbiPath = path.join(
    `artifacts/contracts/${domainName}/${contractName}.sol/${contractName}.json`
  );
  const contractAbiObject = JSON.parse(
    fs.readFileSync(contractAbiPath).toString()
  );
  const contractAbi = contractAbiObject["abi"];
  const contractAddress = getContractAddress(contractName);
  const contract = new ethers.Contract(contractAddress, contractAbi, wallet);

  return contract;
}
