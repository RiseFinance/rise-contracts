import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.18",
  networks: {
    l3local: {
      url: "http://localhost:8449", // Local Arbitrum L3 node
      accounts: [process.env.DEPLOY_PRIVATE_KEY as string], // 0xDe264e2133963c9f40e07f290E1D852f7e4e4c7c
    },
  },
};

export default config;
