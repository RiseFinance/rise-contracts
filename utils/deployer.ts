import { ethers } from "hardhat";

export async function deployContract(
  contractName: string,
  contructorArgs: any[] | undefined = []
) {
  const contractFactory = await ethers.getContractFactory(contractName);
  const contract = await contractFactory.deploy(...contructorArgs);
  console.log(`>>> ${contractName} Deployment in progress...`);
  await contract.deployed();
  console.log(`>>> ${contractName} Deployed.`);
  return contract;
}
