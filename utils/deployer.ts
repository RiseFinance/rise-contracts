import { ethers } from "hardhat";

export async function deployContract(
  contractName: string,
  contructorArgs: any[] | undefined = [],
  libraryAddress: string | undefined = undefined
) {
  let contractFactory;

  if (libraryAddress) {
    contractFactory = await ethers.getContractFactory(contractName, {
      libraries: {
        MathUtils: libraryAddress, // FIXME: now hardcoded
      },
    });
  } else {
    contractFactory = await ethers.getContractFactory(contractName);
  }

  const contract = await contractFactory.deploy(...contructorArgs);
  await contract.deployed();
  console.log(`>>> ${contractName} Deployed.`);
  return contract;
}
