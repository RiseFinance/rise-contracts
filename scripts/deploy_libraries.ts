import * as fs from "fs";
import { deployContract } from "../utils/deployer";

export async function deployLibraries() {
  const mathUtils = await deployContract("MathUtils");

  const libraryAddresses = {
    MathUtils: mathUtils.address,
  };

  fs.writeFileSync(
    __dirname + "/output/Addresses.json",
    JSON.stringify({ Library: libraryAddresses }, null, 2),
    { flag: "w" }
  );

  return mathUtils;
}
