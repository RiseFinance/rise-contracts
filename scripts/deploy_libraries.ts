import * as fs from "fs";
import { deployContract } from "../utils/deployer";

export type libraryAddresses = {
  mathUtils: string;
  orderUtils: string;
  positionUtils: string;
};

async function main() {
  await deployLibraries();
}

async function deployLibraries() {
  const mathUtils = await deployContract("MathUtils");
  const orderUtils = await deployContract("OrderUtils");
  const positionUtils = await deployContract("PositionUtils", [], {
    MathUtils: mathUtils.address,
  });
  const pnlUtils = await deployContract("PnlUtils");

  const libraryAddresses = {
    MathUtils: mathUtils.address,
    OrderUtils: orderUtils.address,
    PositionUtils: positionUtils.address,
    PnlUtils: pnlUtils.address,
  };

  fs.writeFileSync(
    __dirname + "/output/libraryAddresses.json",
    JSON.stringify({ Library: libraryAddresses }, null, 2),
    { flag: "w" }
  );

  return libraryAddresses;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
