import * as path from "path";
import * as fs from "fs";
import { Network } from "./network";

export function getContractAddress(contractName: string, network: Network) {
  const addressesPath = path.join(`scripts/output/contractAddresses.json`);
  const addressesObject = JSON.parse(fs.readFileSync(addressesPath).toString());

  const contractAddress = addressesObject[network][contractName];

  return contractAddress;
}
