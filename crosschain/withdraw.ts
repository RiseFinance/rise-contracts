import { ethers } from "ethers";
import { getContract, Network } from "../utils/getContract";

async function main() {
  try {
    // ========================= Set Contract  =========================

    const l2MarginGateway = getContract(
      "crosschain",
      "L2MarginGateway",
      Network.L2
    );

    // ==================== Call Contract Functions ====================
    console.log(">>> withdraw tUSDC from L3Gateway, trigger from L2...");

    const gasParams = {
      _maxSubmissionCost: ethers.utils.parseEther("0.01"),
      _gasLimit: ethers.BigNumber.from("3000000"),
      _gasPriceBid: ethers.BigNumber.from("150000000"),
    };
    const tx = await l2MarginGateway.triggerWithdrawalFromL2(
      0, // _assetId (0: tUSDC)
      ethers.utils.parseEther("1500"), // _withdrawAmount (1500 tUSDC)
      gasParams,
      {
        value: ethers.utils.parseEther("0.01045"), // msg.value = maxSubmissionCost + (gasLimit * gasPriceBid) = 0.01 + 0.00045 = 0.01045 ETH
        gasLimit: ethers.BigNumber.from("3000000"),
      }
    );
    tx.wait();
    console.log(">>> triggerWithdrawalFromL2 tx: ", tx.hash);

    // =================================================================
  } catch (e) {
    console.log(e);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
