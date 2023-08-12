import { HardhatUserConfig } from "hardhat/config";
import "solidity-coverage";
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
  etherscan: {
    apiKey: process.env.ARBISCAN_API_KEY as string,
    customChains: [
      {
        network: "l3local",
        chainId: 71349615649,
        urls: {
          apiURL: "http://localhost:4000/api",
          browserURL: "http://localhost:4000",
        },
      },
    ],
  },
};

export default config;
