import { ethers } from "ethers";
import { getContract, Network } from "../utils/getContract";
import { getPresetAddress } from "../utils/getPresetAddress";
import { getContractAddress } from "../utils/getContractAddress";

// check test USDC balance on L2

async function main() {
  try {
    // ========================= Set Contract  =========================
    const testUsdc = getContract("token", "TestUSDC", Network.L2);
    // ==================== Call Contract Functions ====================

    const deployer = getPresetAddress("deployer");
    const l2Vault = getContractAddress("L2Vault");

    const tokenSymbol = await testUsdc.symbol();

    console.log(
      ">>> Deployer's tUSDC allowance for L2Vault on L2 : ",
      ethers.utils.formatEther(await testUsdc.allowance(deployer, l2Vault)), // _owner, _spender
      tokenSymbol
    );

    // =================================================================
  } catch (e) {
    console.log(e);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
