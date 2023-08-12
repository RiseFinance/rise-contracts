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

    const deployer = await getPresetAddress("deployer");

    const tokenSymbol = await testUsdc.symbol();
    console.log(">> tokenSymbol: ", tokenSymbol);
    console.log(
      ">>> Total Supply: ",
      ethers.utils.formatEther(await testUsdc.totalSupply())
    );
    console.log(">>> Name: ", await testUsdc.name());
    console.log(">>> Symbol: ", tokenSymbol);

    console.log("---------------------------------");

    console.log(
      ">>> Deployer's tUSDC balance on L2 : ",
      ethers.utils.formatEther(await testUsdc.balanceOf(deployer)),
      tokenSymbol
    );

    console.log(
      ">>> L2Vault's tUSDC balance on L2 : ",
      ethers.utils.formatEther(
        await testUsdc.balanceOf(getContractAddress("L2Vault"))
      ),
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
