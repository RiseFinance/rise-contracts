import * as path from "path";
import * as fs from "fs";
import { ContractType } from "../utils/enum";

export function getContractAddress(
  contractName: string,
  contractType: ContractType
) {
  const addressesPath = path.join(`scripts/output/contractAddresses.json`);
  const addressesObject = JSON.parse(fs.readFileSync(addressesPath).toString());

  const contractAddress = addressesObject[contractType][contractName];

  return contractAddress;
}
