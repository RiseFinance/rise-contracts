import { ethers } from "ethers";
import { Network } from "../utils/network";
import { getContract } from "../utils/getContract";
import { getPresetAddress } from "../utils/getPresetAddress";
import { getContractAddress } from "../utils/getContractAddress";

async function main() {
  try {
    // ========================= Set Contract  =========================
    const testUsdc = getContract("token", "TestUSDC", Network.L2);
    // ==================== Call Contract Functions ====================

    const deployer = getPresetAddress("deployer");
    const l2Vault = getContractAddress("L2Vault", Network.L2);
    const tokenSymbol = await testUsdc.symbol();

    console.log(
      ">>> Initial allowance:",
      ethers.utils.formatEther(await testUsdc.allowance(deployer, l2Vault)), // _owner, _spender
      tokenSymbol
    );

    const _amount = ethers.utils.parseEther("300000");

    const tx = await testUsdc.approve(l2Vault, _amount); // _spender, _value
    tx.wait();
    console.log(">>> Approved.");

    console.log(
      ">>> Final allowance:",
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
