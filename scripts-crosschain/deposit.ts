import { ethers } from "hardhat";
import { getContract, Network } from "../utils/getContract";
import { getContractAddress } from "../utils/getContractAddress";

async function main() {
  try {
    // ========================= Set Contract  =========================

    const l2MarginGateway = await getContract(
      "crosschain",
      "L2MarginGateway",
      Network.L2
    );

    // ==================== Call Contract Functions ====================
    const usdcAddress = getContractAddress("USDC");

    const depositAmount = ethers.utils.parseUnits("350", 6); // 350 USDC
    const _maxSubmissionCost = ethers.utils.parseEther("0.1");
    const _gasLimit = ethers.BigNumber.from("3000000");
    const _gasPriceBid = ethers.BigNumber.from("150000000"); // 0.15gwei
    const gasParams = {
      maxSubmissionCost: _maxSubmissionCost,
      gasLimit: _gasLimit,
      gasPriceBid: _gasPriceBid,
    };
    const tx = await l2MarginGateway.depositERC20ToL3(
      usdcAddress, // _token
      depositAmount, // _depositAmount
      gasParams, // L2ToL3FeeParams
      {
        gasLimit: ethers.BigNumber.from("3000000"),
      }
    );
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
