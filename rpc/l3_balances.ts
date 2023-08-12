import { getContract, Network } from "../utils/getContract";

// check test USDC balance on L2

async function main() {
  try {
    // ========================= Set Contract  =========================

    const traderVault = await getContract("account", "TraderVault", Network.L3);

    // ==================== Call Contract Functions ====================

    // =================================================================
  } catch (e) {
    console.log(e);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
