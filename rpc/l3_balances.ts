import { ethers } from "ethers";
import { getContract } from "../utils/getContract";
import { getPresetAddress } from "../utils/getPresetAddress";
import { getContractAddress } from "../utils/getContractAddress";
import { Network } from "../utils/network";

// check test USDC balance on L2

async function main() {
  try {
    // ========================= Set Contract  =========================

    const traderVault = getContract("account", "TraderVault", Network.L3);
    const tokenInfo = getContract("market", "TokenInfo", Network.L2);

    // ==================== Call Contract Functions ====================

    const deployer = getPresetAddress("deployer");
    const usdcAddress = getContractAddress("TestUSDC", Network.L2);

    const usdcAssetId = await tokenInfo.getAssetIdFromTokenAddress(usdcAddress);

    const traderBalance = await traderVault.getTraderBalance(
      deployer,
      usdcAssetId
    );
    console.log("---------------------------------");
    console.log(
      ">>> TraderVault.traderBalance on L3: ",
      ethers.utils.formatEther(traderBalance),
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
