import { deployContract } from "../utils/deployer";

export async function deployLibraries() {
  const mathUtils = await deployContract("MathUtils");

  return mathUtils;
}
