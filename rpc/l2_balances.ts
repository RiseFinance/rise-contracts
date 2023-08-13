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

    console.log("---------------------------------");

    console.log(
      ">>> Deployer's tUSDC balance on L2 : ",
      ethers.utils.formatEther(await testUsdc.balanceOf(deployer)),
      "tUSDC"
    );

    console.log(
      ">>> L2Vault's tUSDC balance on L2 : ",
      ethers.utils.formatEther(
        await testUsdc.balanceOf(getContractAddress("L2Vault"))
      ),
      "tUSDC"
    );
    console.log("---------------------------------");

    // =================================================================
  } catch (e) {
    console.log(e);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
