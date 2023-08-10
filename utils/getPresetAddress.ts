import * as path from "path";
import * as fs from "fs";

export function getPresetAddress(contractName: string) {
  const addressesPath = path.join(`scripts/input/presetAddresses.json`);
  const addressesObject = JSON.parse(fs.readFileSync(addressesPath).toString());

  let contractAddress;

  // check Library first then L2 then L3

  return addressesObject[contractName];
}
