import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100,
      },
    },
  },
  networks: {
    l3local: {
      url: "http://localhost:8449", // Local Arbitrum L3 node
      // accounts: [process.env.DEPLOY_PRIVATE_KEY as string], // 0xDe264e2133963c9f40e07f290E1D852f7e4e4c7c
      accounts: [
        "0x3b2f75dc1c2700d77a13ad478847a46a97964187eab64c911db541c2e4278694",
      ],
    },
    l2local: {
      url: "http://127.0.0.1:7545", // Local Ganache L2 node
      accounts: [
        "0x3b2f75dc1c2700d77a13ad478847a46a97964187eab64c911db541c2e4278694",
      ],
    },
  },
};

export default config;
