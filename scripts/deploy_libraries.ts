import * as fs from "fs";
import { deployContract } from "../utils/deployer";

async function main() {
  await deployLibraries();
}

async function deployLibraries() {
  const mathUtils = await deployContract("MathUtils");

  const libraryAddresses = {
    MathUtils: mathUtils.address,
  };

  fs.writeFileSync(
    __dirname + "/output/contractAddresses.json",
    JSON.stringify({ Library: libraryAddresses }, null, 2),
    { flag: "w" }
  );

  return mathUtils;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
