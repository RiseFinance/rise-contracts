import { ethers } from "hardhat";

export type libraryAddresses = {
  MathUtils?: string;
  OrderUtils?: string;
  PositionUtils?: string;
  PnlUtils?: string;
};

export async function deployContract(
  contractName: string,
  contructorArgs: any[] | undefined = [],
  libraryAddresses?: libraryAddresses
) {
  let contractFactory;

  if (libraryAddresses) {
    contractFactory = await ethers.getContractFactory(contractName, {
      libraries: libraryAddresses,
    });
  } else {
    contractFactory = await ethers.getContractFactory(contractName);
  }

  const contract = await contractFactory.deploy(...contructorArgs);
  await contract.deployed();
  console.log(`>>> ${contractName} Deployed.`);
  return contract;
}
