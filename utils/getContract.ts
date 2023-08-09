import { ethers } from "hardhat";
import * as path from "path";
import * as fs from "fs";

export async function getContract(
  contractName: string,
  contractAddress: string,
  wallet: any
) {
  const contractAbiPath = path.join(
    `artifacts/contracts/${contractName}.sol/${contractName}.json`
  );
  const contractAbiObject = JSON.parse(
    fs.readFileSync(contractAbiPath).toString()
  );
  const contractAbi = contractAbiObject["abi"];
  const contract = new ethers.Contract(contractAddress, contractAbi, wallet);

  return contract;
}
