import * as path from "path";
import * as fs from "fs";

export function getContractAddress(contractName: string) {
  const addressesPath = path.join(`scripts/output/Addresses.json`);
  const addressesObject = JSON.parse(fs.readFileSync(addressesPath).toString());

  let contractAddress;

  if (addressesObject["L3"][contractName] === undefined) {
    contractAddress = addressesObject["L2"][contractName];
  } else {
    contractAddress = addressesObject["L3"][contractName];
  }

  return contractAddress;
}
