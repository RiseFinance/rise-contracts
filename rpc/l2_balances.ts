import { ethers } from "ethers";
import { getContract, Network } from "../utils/getContract";

// check test USDC balance on L2

async function main() {
  try {
    // ========================= Set Contract  =========================
    const testUsdc = await getContract("token", "TestUSDC", Network.L2);

    // ==================== Call Contract Functions ====================
    const tokenSymbol = await testUsdc.symbol();
    console.log(">> tokenSymbol: ", tokenSymbol);
    console.log(
      ">>> Total Supply: ",
      ethers.utils.formatEther(await testUsdc.totalSupply())
    );
    console.log(">>> Name: ", await testUsdc.name());
    console.log(">>> Symbol: ", tokenSymbol);

    // console.log(
    //   ">>> Balance of deployer: ",
    //   ethers.utils.formatEther(await contract.balanceOf(wallet.address)),
    //   tokenSymbol
    // );

    // =================================================================
  } catch (e) {
    console.log(e);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
