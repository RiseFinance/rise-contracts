import * as path from "path";
import * as fs from "fs";

export function getLibraryAddress(contractName: string) {
  const addressesPath = path.join(`scripts/output/libraryAddresses.json`);
  const addressesObject = JSON.parse(fs.readFileSync(addressesPath).toString());

  const contractAddress = addressesObject["Library"][contractName];

  return contractAddress;
}
