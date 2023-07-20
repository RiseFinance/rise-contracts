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
      url: "http://localhost:8449",
      accounts: [process.env.DEPLOY_PRIVATE_KEY as string],
    },
    l2local: {
      url: "http://127.0.0.1:7545",
      accounts: [process.env.DEPLOY_PRIVATE_KEY as string],
    },
    l2testnet: {
      url: "https://goerli-rollup.arbitrum.io/rpc", // Arbitrum Testnet
      accounts: [process.env.DEPLOY_PRIVATE_KEY as string],
    },
  },
};

export default config;
