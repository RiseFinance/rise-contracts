import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // ==================== Set Contract Factory & Constructor ====================
  const L2MarginGatewayContract = await ethers.getContractFactory(
    "L2MarginGateway"
  );
  console.log(">>> got contract factories");

  // ==================== Deploy Contracts ====================

  const _inbox = "0xC78D420557C42467a760A8792739BF982c9144B5";
  const _l2Vault = "0xC78D420557C42467a760A8792739BF982c9144B5";
  const _tokenInfo = "0xC78D420557C42467a760A8792739BF982c9144B5";

  const l2MarginGatewayContract = await L2MarginGatewayContract.deploy(
    _inbox,
    _l2Vault,
    _tokenInfo
  );
  console.log("\n>>> TokenInfo Deployment in progress...");
  await l2MarginGatewayContract.deployed();
  console.log(
    `Deployed TokenInfo Contract: ${l2MarginGatewayContract.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.a
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
