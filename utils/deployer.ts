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
  libraryAddresses?: libraryAddresses,
  isForTest?: boolean
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
  if (!isForTest) {
    console.log(`>>> ${contractName} Deployed.`);
  }
  return contract;
}
