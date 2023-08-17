import * as path from "path";
import * as fs from "fs";

export function getPresetAddress(name: string) {
  const addressesPath = path.join(`scripts/input/presetAddresses.json`);
  const addressesObject = JSON.parse(fs.readFileSync(addressesPath).toString());

  return addressesObject[name];
}
