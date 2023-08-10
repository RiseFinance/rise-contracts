import { ethers } from "hardhat";
import { getContract } from "../utils/getContract";

async function main() {
  try {
    // ==================== Set Contract Name ====================
    const contractName = "L2MarginGateway";
    const contractAddress = "";
    // ===========================================================

    const privateKey = process.env.CHARLIE_PRIVATE_KEY as string;
    const l2Provider = new ethers.providers.JsonRpcProvider(
      "https://goerli-rollup.arbitrum.io/rpc"
    );
    const l2Wallet = new ethers.Wallet(privateKey, l2Provider);

    const contract = await getContract(contractName, contractAddress, l2Wallet);
    // ==================== Call Contract Functions ====================
    const usdcAddress = "0x7B32B8ef823D63cA9E5ee3dB84FF1576549C45ed";

    const depositAmount = ethers.utils.parseUnits("350", 6); // 350 USDC
    const _maxSubmissionCost = ethers.utils.parseEther("0.1");
    const _gasLimit = ethers.BigNumber.from("3000000");
    const _gasPriceBid = ethers.BigNumber.from("150000000"); // 0.15gwei
    const gasParams = {
      maxSubmissionCost: _maxSubmissionCost,
      gasLimit: _gasLimit,
      gasPriceBid: _gasPriceBid,
    };
    const tx = await contract.depositERC20ToL3(
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
