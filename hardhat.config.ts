import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable, defineConfig } from "hardhat/config";

import { config as dotenvConfig } from "dotenv";

dotenvConfig();

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin],
  solidity: {
    profiles: {
      default: {
        version: "0.8.24",
      },
      production: {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
    npmFilesToBuild: [
      "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol",
    ],
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
    arbitrum: {
      type: "http",
      chainType: "l1",
      url: configVariable("ARBITRUM_RPC_URL"),
      accounts: [configVariable("ARBITRUM_PRIVATE_KEY")],
    },
  },
  verify: {
    etherscan: {
      // 统一的 Etherscan V2 API key
      apiKey: configVariable("ETHERSCAN_API_KEY"),
    },
  },
});
