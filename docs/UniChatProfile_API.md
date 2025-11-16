## UniChatProfile 前端调用接口文档

说明

- 合约类型：可转让 ERC-721（含 tokenURI）+ UUPS 可升级（可一次性封印升级）。
- 接口来源：`contracts/IUniChatProfile.sol`、`contracts/UniChatProfile.sol`。
- 性能提示：`getProfilesOf` 为线性遍历，建议仅在 off-chain/后端使用。

### 准备工作

- 交互地址：请使用 Proxy 地址与 ABI 进行交互（UUPS 架构）。

```ts
// viem 示例
import { createPublicClient, createWalletClient, http, getAbiItem } from 'viem';
import { mainnet } from 'viem/chains';
import UniChatProfileAbi from './abi/UniChatProfile.json';

const publicClient = createPublicClient({ chain: mainnet, transport: http() });
const walletClient = createWalletClient({ chain: mainnet, transport: http() });

const CONTRACT_ADDRESS = '0xYourProxyAddress';
```

### 结构体

- Profile

  - name: string（昵称，长度 1-64）
  - description: string（个人简介，长度 ≤512）
  - avatarCid: string（头像 IPFS CID，不含协议前缀）
  - createdAt: uint64（创建时间戳）
  - updatedAt: uint64（最近更新时间戳）
- ProfileView

  - tokenId: uint256
  - owner: address
  - name: string
  - description: string
  - avatarCid: string
  - createdAt: uint64
  - updatedAt: uint64
  - tokenUri: string（通常为 ipfs://CID）

### 事件

- ProfileMinted(address indexed owner, uint256 indexed tokenId)
- ProfileUpdated(address indexed operator, uint256 indexed tokenId)
- ProfileBurned(address indexed operator, uint256 indexed tokenId)
- DefaultAvatarCidSet(string cid)
- UpgradeDisabled()

订阅示例：

```ts
// viem：建议通过日志过滤器读取（前端实时订阅可使用轮询或第三方服务）
const eventAbi = UniChatProfileAbi.find((x) => x.type === 'event' && x.name === 'ProfileMinted');
const { logs } = await publicClient.getLogs({
  address: CONTRACT_ADDRESS,
  event: eventAbi as any,
  fromBlock: 'latest'
});
```

### 可写函数（external）

#### mintProfile(name, description, useDefaultAvatarFlag, avatarCidOrEmpty, tokenUri) → uint256

- 作用：为调用者自己铸造一张资料卡 NFT。
- 权限：任何地址均可调用。
- 校验：
  - name 长度 1-64；description 长度 ≤512。
  - useDefaultAvatarFlag 为 true 时，avatarCidOrEmpty 应为空串；否则必须非空。
  - tokenUri 必须非空（通常为 `ipfs://...`）。

viem：

```ts
import { parseAbi } from 'viem';

const hash = await walletClient.writeContract({
  address: CONTRACT_ADDRESS,
  abi: UniChatProfileAbi,
  functionName: 'mintProfile',
  args: ['Alice', 'Hello UniChat!', true, '', 'ipfs://bafy...']
});
const receipt = await publicClient.waitForTransactionReceipt({ hash });
```

#### updateProfile(tokenId, newName, newDescription, newAvatarCid, newTokenUri)

- 作用：更新资料任意字段；传入空串表示“不修改该字段”。
- 权限：token 拥有者或合约 owner。

viem：

```ts
const hash = await walletClient.writeContract({
  address: CONTRACT_ADDRESS,
  abi: UniChatProfileAbi,
  functionName: 'updateProfile',
  args: [1n, '', 'New bio here', '', 'ipfs://newMetaCid']
});
await publicClient.waitForTransactionReceipt({ hash });
```

#### useDefaultAvatar(tokenId)

- 作用：将头像恢复为“当前全局默认头像 CID”。
- 权限：token 拥有者或合约 owner。

```ts
// viem
await publicClient.waitForTransactionReceipt({
  hash: await walletClient.writeContract({
    address: CONTRACT_ADDRESS,
    abi: UniChatProfileAbi,
    functionName: 'useDefaultAvatar',
    args: [1n]
  })
});
```

#### burnProfile(tokenId)

- 作用：销毁资料卡（对应 token 被 `_burn`）。
- 权限：token 拥有者或合约 owner。

```ts
// ethers v6
await (await contract.burnProfile(1n)).wait();
```

#### setDefaultAvatarCid(cid)

- 作用：设置全局默认头像 CID（非空）。
- 权限：onlyOwner。

```ts
// viem
await publicClient.waitForTransactionReceipt({
  hash: await walletClient.writeContract({
    address: CONTRACT_ADDRESS,
    abi: UniChatProfileAbi,
    functionName: 'setDefaultAvatarCid',
    args: ['bafyDefaultCid...']
  })
});
```

#### disableUpgrade()

- 作用：永久封印升级能力，不可逆。
- 权限：onlyOwner。

```ts
// ethers v6
await (await contract.disableUpgrade()).wait();
```

### 只读函数（view）

#### getProfile(tokenId) → ProfileView

```ts
// viem
const p = await publicClient.readContract({
  address: CONTRACT_ADDRESS,
  abi: UniChatProfileAbi,
  functionName: 'getProfile',
  args: [1n]
});
```

#### getProfilesOf(user) → uint256[]

- 注意：内部从 1 遍历到当前 supply（gas 高），建议后端/索引层调用，前端避免直调。

```ts
const ids = await publicClient.readContract({
  address: CONTRACT_ADDRESS,
  abi: UniChatProfileAbi,
  functionName: 'getProfilesOf',
  args: ['0xUserAddress']
});
```

#### hasProfile(user) → bool

```ts
const ok = await publicClient.readContract({
  address: CONTRACT_ADDRESS,
  abi: UniChatProfileAbi,
  functionName: 'hasProfile',
  args: ['0xUserAddress']
});
```

#### defaultAvatarCid() → string

```ts
const cid = await publicClient.readContract({
  address: CONTRACT_ADDRESS,
  abi: UniChatProfileAbi,
  functionName: 'defaultAvatarCid',
  args: []
});
```

#### upgradeDisabled() → bool

```ts
const sealed = await publicClient.readContract({
  address: CONTRACT_ADDRESS,
  abi: UniChatProfileAbi,
  functionName: 'upgradeDisabled',
  args: []
});
```

### ERC-721 常用接口

- balanceOf(owner) → uint256
- ownerOf(tokenId) → address
- tokenURI(tokenId) → string
- approve(to, tokenId)、setApprovalForAll(operator, approved)
- transferFrom(from, to, tokenId)、safeTransferFrom(from, to, tokenId[, data])

```ts
// ethers v6 转移 NFT
await (await contract.transferFrom('0xFrom', '0xTo', 1n)).wait();
```

### 常见前端流程

- 铸造资料卡

  - 连接钱包 → 准备 name/description 与头像策略 → 上传 JSON metadata 至 IPFS 得到 tokenUri → 调用 `mintProfile` → 监听 `ProfileMinted`。
- 更新资料卡

  - 仅改动需要更新的字段，其它传空串；更新 tokenURI 时，先上传新 JSON，再调用 `updateProfile`。
- 恢复默认头像

  - 调用 `useDefaultAvatar`（若后续默认头像被 owner 更新，已恢复到默认的 token 会保持当时的默认值，除非再次恢复）。

### 错误与边界

- 名称校验失败：`"Name length invalid"`（长度需 1-64）。
- 简介过长：`"Description too long"`（≤512）。
- 头像 CID 规则：
  - 使用默认头像：`useDefaultAvatarFlag=true` 且 `avatarCidOrEmpty` 应为空串。
  - 使用自定义头像：`useDefaultAvatarFlag=false` 且 `avatarCidOrEmpty` 必须非空，否则 `"Avatar CID required"`。
- tokenUri 必须非空：`"tokenURI required"`。
- 资源存在性：读取/更新/销毁需 token 存在，否则 `"Profile: nonexistent token"`。
- 权限错误：更新/恢复默认头像/销毁仅 token 拥有者或合约 owner；设置默认头像、封印升级为 onlyOwner；升级时若已封印则 `"Upgrade disabled"`。

### 集成要点

- UUPS 架构务必使用 Proxy 地址与 ABI 交互。
- `getProfilesOf` 建议由后端/索引层实现（如 The Graph），前端仅消费 API，避免前端直调导致性能问题。
- IPFS：头像仅存 CID（不含协议），前端展示时拼接网关前缀；`tokenUri` 建议为 `ipfs://{cid}` 完整 URI。

 ### tokenURI 元数据 JSON 格式（ERC-721 Metadata）
 
 - 合约不校验具体 JSON 结构，只存储 `tokenUri` 字符串；前端/平台通常遵循 OpenSea/ERC-721 Metadata 约定。
 - 推荐字段：
   - `name`: string，NFT 名称（可与链上 `Profile.name` 一致）。
   - `description`: string，NFT 描述（可与链上 `Profile.description` 一致）。
   - `image`: string，指向图片资源的完整 URI，推荐 `https://gateway.pinata.cloud/ipfs/{avatarCid}` 或网关 URL。
   - `external_url`: string，项目内该资料卡的 Web 页面地址（可选）。
   - `attributes`: Attribute[]，特征数组（可选，便于展示/检索）。
   - `background_color`: string，6 位十六进制色（可选）。
   - `animation_url`: string，若是视频或交互式页面可用（可选）。
 
 示例（与 `UniChatProfile.sol` 中 `mintProfile/updateProfile` 搭配使用）：
 
 ```json
 {
   "name": "Alice",
   "description": "Hello UniChat!",
   "image": "ipfs://bafyAvatarCid...", 
   "external_url": "https://app.unichat.xyz/profile/1",
   "attributes": [
     { "trait_type": "Profile ID", "value": "1" },
     { "trait_type": "Created At", "display_type": "date", "value": 1731696000 },
     { "trait_type": "Updated At", "display_type": "date", "value": 1731782400 }
   ],
   "background_color": "ffffff"
 }
 ```
 
 说明：
 - `image`：建议直接使用 `https://gateway.pinata.cloud/ipfs/{avatarCid}`。若你在 IPFS 上存放的是文件夹/打包资源，也可填写具体文件路径（如 `ipfs://{cid}/avatar.png`）。
 - `name/description`：可与链上存储保持一致，更新资料后若需要前端/平台展示同步，建议重新生成并更新 `tokenUri`（调用 `updateProfile` 的 `newTokenUri`）。
 - `attributes`：便于二级市场或前端筛选、展示，不是必填。
 - 大小与编码：建议 JSON 与图片资源体积适中，避免过大；UTF-8 编码。
 - 网关兼容：如果目标平台不支持原生 `ipfs://`，可在前端渲染时替换为网关 URL（如 `https://ipfs.io/ipfs/{cid}`）。
 