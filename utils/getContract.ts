import { ethers } from "hardhat";
import * as path from "path";
import * as fs from "fs";

export async function getContract(
  directoryName: string,
  contractName: string,
  contractAddress: string,
  wallet: any | undefined = undefined
) {
  const contractAbiPath = path.join(
    `artifacts/contracts/${directoryName}/${contractName}.sol/${contractName}.json`
  );
  const contractAbiObject = JSON.parse(
    fs.readFileSync(contractAbiPath).toString()
  );
  const contractAbi = contractAbiObject["abi"];
  const contract = new ethers.Contract(contractAddress, contractAbi, wallet);

  return contract;
}
