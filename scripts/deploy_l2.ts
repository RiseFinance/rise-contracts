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

  //   const _inbox = "0x0A0dD8845C0064f03728F7f145B7DDA05FD0Ccc6";
  //   const _l2Vault = "";
  //   const _tokenInfo = "";

  //   const l2MarginGatewayContract = await L2MarginGatewayContract.deploy(
  //     _inbox,
  //     _l2Vault,
  //     _tokenInfo
  //   );
  //   console.log("\n>>> TokenInfo Deployment in progress...");
  //   await l2MarginGatewayContract.deployed();
  //   console.log(
  //     `Deployed TokenInfo Contract: ${l2MarginGatewayContract.address}`
  //   );

  await deployL2Contracts();
}

// L2 Contracts

async function deployL2Contracts() {
  // Nitro Contracts
  const _inbox = "0x0A0dD8845C0064f03728F7f145B7DDA05FD0Ccc6";

  // test USDC
  const Usdc = await ethers.getContractFactory("USDC");
  const usdc = await Usdc.deploy();
  console.log(">>> test USDC Deployment in progress...");
  await usdc.deployed();
  console.log(">>> test USDC Deployed.");

  // Market
  const Market = await ethers.getContractFactory("Market");
  const market = await Market.deploy();
  console.log(">>> Market Deployment in progress...");
  await market.deployed();
  console.log(">>> Market Deployed.");

  // TokenInfo
  const TokenInfo = await ethers.getContractFactory("TokenInfo");
  const tokenInfo = await TokenInfo.deploy(market.address);
  console.log(">>> TokenInfo Deployment in progress...");
  await tokenInfo.deployed();
  console.log(">>> TokenInfo Deployed.");

  // L2Vault
  const L2Vault = await ethers.getContractFactory("L2Vault");
  const l2Vault = await L2Vault.deploy();
  console.log(">>> L2Vault Deployment in progress...");
  await l2Vault.deployed();
  console.log(">>> L2Vault Deployed.");

  //L2MarginGateway
  const L2MarginGateway = await ethers.getContractFactory("L2MarginGateway");
  const l2MarginGateway = await L2MarginGateway.deploy(
    _inbox,
    l2Vault.address,
    tokenInfo.address
  );
  console.log(">>> L2MarginGateway Deployment in progress...");
  await l2MarginGateway.deployed();
  console.log(">>> L2MarginGateway Deployed.");

  // RisePoolUtils
  const RisePoolUtils = await ethers.getContractFactory("RisePoolUtils");
  const risePoolUtils = await RisePoolUtils.deploy();
  console.log(">>> RisePoolUtils Deployment in progress...");
  await risePoolUtils.deployed();
  console.log(">>> RisePoolUtils Deployed.");

  //L2LiquidityGateway
  const L2LiquidityGateway = await ethers.getContractFactory(
    "L2LiquidityGateway"
  );
  const l2LiquidityGateway = await L2LiquidityGateway.deploy(
    _inbox,
    l2Vault.address,
    market.address,
    risePoolUtils.address
  );
  console.log(">>> L2LiquidityGateway Deployment in progress...");
  await l2LiquidityGateway.deployed();
  console.log(">>> L2LiquidityGateway Deployed.");

  console.log("---------------------------------------------");
  console.log(">>> L2 Contracts Deployed.");
  console.log(">>> test USDC: ", usdc.address);
  console.log(">>> Market: ", market.address);
  console.log(">>> TokenInfo: ", tokenInfo.address);
  console.log(">>> L2Vault: ", l2Vault.address);
  console.log(">>> L2MarginGateway: ", l2MarginGateway.address);
  console.log(">>> RisePoolUtils: ", risePoolUtils.address);
  console.log(">>> L2LiquidityGateway: ", l2LiquidityGateway.address);
  console.log("---------------------------------------------");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
