import * as path from "path";
import * as fs from "fs";

export function getContractAddress(contractName: string) {
  const addressesPath = path.join(`scripts/output/contractAddresses.json`);
  const addressesObject = JSON.parse(fs.readFileSync(addressesPath).toString());

  let contractAddress;

  // check Library first then L2 then L3
  if (addressesObject["Library"][contractName] !== undefined) {
    contractAddress = addressesObject["Library"][contractName];
  } else if (addressesObject["L2"][contractName] !== undefined) {
    contractAddress = addressesObject["L2"][contractName];
  } else {
    contractAddress = addressesObject["L3"][contractName];
  }

  return contractAddress;
}
