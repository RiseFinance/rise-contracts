import { ethers } from "ethers";
import * as path from "path";
import * as fs from "fs";
import dotenv from "dotenv";
import { Metadata } from "../utils/metadata";

dotenv.config();

async function main() {
  try {
    const meta = new Metadata();
    // ==================== Set Contract Name ====================
    const contractName = meta.L3VAULT_CONTRACT_NAME;
    const contractAddress = meta.L3VAULT_CONTRACT_ADDRESS;
    // ===========================================================

    const privateKey = process.env.PRIVATE_KEY as string;
    const provider = new ethers.providers.JsonRpcProvider(meta.rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    const abiPath = path.join(
      `artifacts/contracts/${contractName}.sol/${contractName}.json`
    );
    const abiObject = JSON.parse(fs.readFileSync(abiPath).toString());
    const abi = abiObject["abi"];
    const contract = new ethers.Contract(contractAddress, abi, wallet);

    // // ==================== Call Contract Functions ====================

    // const poolAmounts1 = await contract.tokenPoolAmounts(0);
    // console.log(`Initial poolAmounts: ${poolAmounts1}`);

    // await contract.addLiquidity(0, 180);

    // const poolAmounts2 = await contract.tokenPoolAmounts(0);
    // console.log(`Final poolAmounts: ${poolAmounts2}`);

    // open a position

    const _account = "0x601844915087a902930D8f8c1F6635eD22e1dAeD";
    const _collateralAssetId = 0; // ETH
    const _indexAssetId = 0; // ETH
    const _size = 225; // 225 ETH
    const _collateralSize = 45; // 45 ETH, x5 leverage
    const _isLong = true;

    const positionKey = await contract.openPosition(
      _account,
      _collateralAssetId,
      _indexAssetId,
      _size,
      _collateralSize,
      _isLong,
      {
        gasLimit: 1000000,
      }
    );
    console.log(`Position Key: ${positionKey}`);

    console.log(">>> Get Position ==============================");
    const position = await contract.getPosition(positionKey);
    console.log(position);
    console.log("===============================================");

    // =================================================================
  } catch (e) {
    console.log(e);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
