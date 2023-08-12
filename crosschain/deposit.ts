import { ethers } from "ethers";
import { getContract, Network } from "../utils/getContract";
import { getContractAddress } from "../utils/getContractAddress";

async function main() {
  try {
    // ========================= Set Contract  =========================

    const l2MarginGateway = getContract(
      "crosschain",
      "L2MarginGateway",
      Network.L2
    );

    // ==================== Call Contract Functions ====================
    const usdcAddress = getContractAddress("TestUSDC");

    const depositAmount = ethers.utils.parseUnits("3350", 18); // 1350 USDC

    const gasParams = {
      _maxSubmissionCost: ethers.utils.parseEther("0.01"),
      _gasLimit: ethers.BigNumber.from("3000000"),
      _gasPriceBid: ethers.BigNumber.from("150000000"),
    };
    const tx = await l2MarginGateway.depositERC20ToL3(
      usdcAddress, // _token
      depositAmount, // _depositAmount
      gasParams, // L2ToL3FeeParams
      {
        value: ethers.utils.parseEther("0.01045"), // for L3 gas fee
        gasLimit: ethers.BigNumber.from("3000000"),
      }
    );
    tx.wait();
    console.log(">> tx: ", tx.hash);

    // =================================================================
  } catch (e) {
    console.log(e);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
