# UniChat Profile - Hardhat 3 Beta 项目

这是一个基于 Hardhat 3 Beta 的 UniChat Profile 智能合约项目，使用 Node.js 原生测试运行器 (`node:test`) 和 `viem` 库进行以太坊交互。

了解更多关于 Hardhat 3 Beta 的信息，请访问 [Getting Started guide](https://hardhat.org/docs/getting-started#getting-started-with-hardhat-3)。要分享反馈，请加入 [Hardhat 3 Beta](https://hardhat.org/hardhat3-beta-telegram-group) Telegram 群组或在 GitHub issue tracker 中 [提交问题](https://github.com/NomicFoundation/hardhat/issues/new)。

## 项目概述

本项目包含：

- **UniChatProfile 合约**：一个可升级的 ERC721 NFT 合约，用于表示用户资料卡
  - 使用 UUPS（Universal Upgradeable Proxy Standard）升级模式
  - 支持可转让的用户资料 NFT（非 SBT）
  - 链上存储用户资料信息（name、description、avatarCid、timestamps）
  - 支持 tokenURI，指向 JSON metadata（通常在 IPFS 上）
  - 支持一次性封印升级功能
- Hardhat 配置文件，支持本地网络和 Arbitrum 网络
- TypeScript 集成测试，使用 [`node:test`](https://nodejs.org/api/test.html) 和 [`viem`](https://viem.sh/)
- Ignition 部署模块，支持代理合约部署
- 示例脚本，演示合约交互

## 使用说明

### 安装依赖

使用 pnpm 安装项目依赖：

```shell
pnpm install
```

### 编译合约

编译 Solidity 合约：

```shell
pnpm compile
# 或
npx hardhat compile
```

### 运行测试

运行所有测试：

```shell
pnpm test
# 或
npx hardhat test
```

也可以选择性运行 Solidity 或 `node:test` 测试：

```shell
npx hardhat test solidity
npx hardhat test nodejs
```

### 部署合约

#### 本地部署

部署到本地模拟链：

```shell
pnpm deploy:local
# 或
npx hardhat ignition deploy ignition/modules/UniChatProfileModule.ts
```

#### 部署到 Arbitrum

部署到 Arbitrum 网络需要配置环境变量。项目使用 Hardhat 配置变量来管理敏感信息。

**配置环境变量：**

1. 使用 `hardhat-keystore` 插件设置私钥和 RPC URL：

```shell
npx hardhat keystore set ARBITRUM_PRIVATE_KEY
npx hardhat keystore set ARBITRUM_RPC_URL
npx hardhat keystore set ETHERSCAN_API_KEY
```

2. 或者通过环境变量设置（在 `.env` 文件中）：

```env
ARBITRUM_PRIVATE_KEY=your_private_key
ARBITRUM_RPC_URL=your_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key
```

**执行部署：**

```shell
pnpm deploy:arbitrum
# 或
npx hardhat ignition deploy --network arbitrum --verify --reset ignition/modules/UniChatProfileModule.ts
```

部署时会自动：
- 部署实现合约（UniChatProfile）
- 部署 ERC1967Proxy 代理合约
- 执行初始化函数
- 验证合约（如果配置了 Etherscan API key）

**部署参数：**

可以通过命令行参数覆盖默认值：

```shell
npx hardhat ignition deploy --network arbitrum \
  --parameters '{"UniChatProfileModule":{"defaultAvatarCid":"QmYourDefaultAvatarCid"}}' \
  ignition/modules/UniChatProfileModule.ts
```

### 运行示例脚本

运行示例脚本演示合约交互：

```shell
pnpm scripts:profile-demo
# 或
npx hardhat run scripts/profile-demo.ts
```

### 清理构建文件

清理 artifacts 和 cache 目录：

```shell
pnpm clean
# 或
npx hardhat clean
```

## 项目结构

```
profile-hardhat/
├── contracts/              # Solidity 合约
│   ├── UniChatProfile.sol # 主合约实现
│   └── IUniChatProfile.sol # 接口定义
├── test/                   # 测试文件
│   └── Profile.ts         # TypeScript 集成测试
├── scripts/                # 脚本文件
│   └── profile-demo.ts     # 示例交互脚本
├── ignition/               # Ignition 部署模块
│   └── modules/
│       └── UniChatProfileModule.ts
├── hardhat.config.ts       # Hardhat 配置
└── package.json            # 项目依赖
```

## 技术栈

- **Hardhat 3 Beta**：开发框架
- **Solidity 0.8.24**：智能合约语言
- **OpenZeppelin Contracts**：可升级合约库
- **TypeScript**：类型安全的 JavaScript
- **viem**：以太坊交互库
- **node:test**：Node.js 原生测试运行器
