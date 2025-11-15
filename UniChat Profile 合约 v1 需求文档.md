# UniChat Profile 合约 v1 需求文档

## 0. 背景与目标

UniChat 需要一套**链上用户资料系统**，以 NFT 形式为每个用户提供：

- 可转让的“头像身份卡”（ERC-721 NFT）；

- 链上记录的基础资料（昵称 + 个人简介 + 头像 CID）；

- 支持后续通过可升级合约方式，平滑扩展更多字段（社交账号、标签、等级等）。

本需求文档描述 **v1 版本** 的功能范围、行为规则、存储结构与升级策略。

---

## 1. 技术栈与基础标准

1. 使用 **OpenZeppelin v5 升级版合约库**：
   
   - `@openzeppelin/contracts-upgradeable`（而不是非升级版）。
   
   - 核心基类包括：
     
     - `Initializable`
     
     - `UUPSUpgradeable`
     
     - `OwnableUpgradeable`
     
     - `ERC721Upgradeable`
     
     - 如需链上存 tokenURI，可选择：
       
       - 使用 `ERC721URIStorageUpgradeable`，或
       
       - 自行维护 `mapping(uint256 => string) _tokenURIs` 并重写 `tokenURI`。

2. NFT 标准：
   
   - 遵循 **ERC-721** 标准接口与事件（`IERC721`, `IERC721Metadata`）。

3. 升级标准：
   
   - 采用 **UUPS（Universal Upgradeable Proxy Standard）** 模式，使用 OpenZeppelin 提供的 `UUPSUpgradeable` 实现。

---

## 2. 升级模式与治理（UUPS）

### 2.1 升级模式

- 合约采用 **UUPS 模式**：
  
  - 代理合约为 `ERC1967Proxy`；
  
  - 实现合约继承 `UUPSUpgradeable`；
  
  - 实现 `_authorizeUpgrade(address newImplementation)` 来控制升级权限。

### 2.2 升级管理员

- v1 中，升级权限由合约的 **owner（EOA）** 持有：
  
  - 使用 `OwnableUpgradeable`；
  
  - `initializer` 中通过 `__Ownable_init(msg.sender)` 设置初始 owner；
  
  - `_authorizeUpgrade` 实现为 `onlyOwner`。

### 2.3 封印升级能力

- 合约需要具备**永久禁止后续升级**的能力：
  
  - 设计一个布尔状态变量，如 `bool public upgradeDisabled`；
  
  - `_authorizeUpgrade` 逻辑：
    
    - `require(!upgradeDisabled, "Upgrade disabled");`
    
    - `require(msg.sender == owner(), "Ownable: caller is not the owner");`
  
  - 提供一个仅 owner 调用的一次性函数：
    
    - 如 `function disableUpgrade() external onlyOwner`：
      
      - 将 `upgradeDisabled = true;`
      
      - 发出事件 `UpgradeDisabled()`；
      
      - 该操作不可逆。

### 2.4 多网络部署与治理

- 每条链（如 Arbitrum、BSC、OP 等）各自部署一套 `UniChatProfile`：
  
  - 各合约拥有 **独立的 owner**；
  
  - 各自独立升级，不需要中心化统一治理。

---

## 3. Profile & NFT 行为

### 3.1 NFT 行为总体

- 合约实现一个标准 ERC-721 NFT 集合：
  
  - 名称示例：`"UniChat Profile"`
  
  - 符号示例：`"UCHP"`

- 每个 tokenId 对应一张 Profile 身份卡，可以在地址之间**自由转让**（非 SBT）：
  
  - 标准 `transferFrom` / `safeTransferFrom` 行为；
  
  - 不对 transfer 做特殊限制（除了后续明确的逻辑约束外）。

### 3.2 地址与 Profile NFT 的关系

- 一个地址 **允许持有多张 Profile NFT**：
  
  - 不在合约层面限制“一地址多身份卡”；
  
  - 未来 UniChat 前端可以自己定义“主身份卡”的选择规则（例如取最新铸造的一张或用户手动选择）。

### 3.3 mint 行为

- 提供公开函数 `mintProfile`，用于让用户为自己创建一张新资料卡：
  
  - 函数签名（示意）：
    
    ```solidity
    function mintProfile(
        string calldata name,
        string calldata description,
        bool useDefaultAvatar,
        string calldata avatarCidOrEmpty,
        string calldata tokenUri
    ) external returns (uint256 tokenId);
    ```
  
  - 行为描述：
    
    1. 只允许为 `msg.sender` 铸造：
       
       - 内部使用 `_safeMint(msg.sender, tokenId)`；
       
       - 不接受任意指定 `to` 参数，避免帮别人“强行建档”。
    
    2. 生成新的 `tokenId`（例如从 1 自增的 `_nextTokenId`）。
    
    3. 构造 `Profile` 数据：
       
       - `name` 与 `description` 需满足长度限制（见 4.2）。
       
       - 若 `useDefaultAvatar == true`：
         
         - 使用当前默认头像 CID（见 3.5）。
       
       - 否则：
         
         - 使用 `avatarCidOrEmpty` 作为 `avatarCid`（要求非空）。
       
       - `createdAt` 和 `updatedAt` 为当前 `block.timestamp`。
    
    4. 写入 `_profiles[tokenId]` 映射。
    
    5. 写入 `tokenURI`：
       
       - `tokenUri` 期望为指向 JSON metadata 的 `ipfs://...`；
       
       - 可以直接存储在 `_tokenURIs[tokenId]` 中，或使用 `ERC721URIStorageUpgradeable` 的 `_setTokenURI`。
    
    6. 触发 `ProfileMinted` 事件。

### 3.4 更新资料与头像

- 提供 `updateProfile` 函数：
  
  - 仅 `ownerOf(tokenId)` 或合约 owner（admin）可调用：
    
    - 普通用户只能更新自己拥有的 Profile；
    
    - 合约 owner 可在特殊情况下进行修改（例如管理操作、纠错）。
  
  - 函数示例：
    
    ```solidity
    function updateProfile(
        uint256 tokenId,
        string calldata newName,
        string calldata newDescription,
        string calldata newAvatarCid,
        string calldata newTokenUri
    ) external;
    ```
  
  - 行为规则：
    
    1. 权限判断：
       
       - `msg.sender == ownerOf(tokenId)` 或 `msg.sender == owner()`;
    
    2. 更新字段采用“空串不更新”策略：
       
       - `newName.length > 0` 才更新 name；
       
       - `newDescription.length > 0` 才更新 description；
       
       - `newAvatarCid.length > 0` 才更新 avatarCid；
       
       - `newTokenUri.length > 0` 才更新 tokenURI。
    
    3. 每次调用，无论是否真的有字段改变，都更新 `updatedAt` 为 `block.timestamp`（或者仅在实际有变动时更新，这点可在实现中约定）。
    
    4. 触发一个统一的 `ProfileUpdated` 事件（不拆分 Name/Description/Avatar 事件）。

- 用户通过 `updateProfile` 即可：
  
  - 更改昵称；
  
  - 更改个人简介；
  
  - 更换头像 CID；
  
  - 更新 metadata JSON 的 `tokenURI`。

### 3.5 默认头像策略与多皮肤预留

- v1 实现一个基础的默认头像机制，并预留“多皮肤”扩展空间。
1. **全局默认头像 CID**
   
   - 存储字段：
     
     ```solidity
     string public defaultAvatarCid;
     ```
   
   - 初始化时由 owner 设置，或提供 `setDefaultAvatarCid(string cid)`（仅 owner）。
   
   - `mintProfile` 时如果 `useDefaultAvatar == true`：
     
     - 使用 `defaultAvatarCid` 填充 Profile 的 `avatarCid`。

2. **未来多套默认皮肤预留**
   
   - v1 仅需在文档 & 结构上预留扩展空间，不必实现完整逻辑；
   
   - 预留方式示例：
     
     - 保留一个（暂时不用的）结构或映射：
       
       ```solidity
       // 未来可用：主题 => 默认头像 CID
       // mapping(bytes32 => string) private _defaultAvatarCidByTheme;
       ```
     
     - Profile 结构体中暂不加入 theme 字段（按你“v1 只放最核心字段”的决策），未来通过 UUPS 升级在 Profile 里追加 `bytes32 theme` 或其他字段。

---

## 4. Metadata & 字段约束

### 4.1 tokenURI 策略（M2）

- 采用 **M2 模式**：**链上同时存 profile 字段 + tokenURI**。

- 期望外部 JSON metadata 格式大致为：
  
  ```json
  {
    "name": "UniChat - Alice",
    "description": "Alice 在 UniChat 上的个人资料卡",
    "image": "ipfs://<avatarCid>",
    "attributes": [
      { "trait_type": "UniChat Name", "value": "<name>" },
      { "trait_type": "UniChat Description", "value": "<description>" }
    ]
  }
  ```

- 由前端 / off-chain 服务负责：
  
  - 将 Profile 数据写入 IPFS JSON；
  
  - 在更新资料时同步更新该 JSON，并调用 `updateProfile` 传入新的 `tokenUri`。

### 4.2 字段长度限制（适中）

为兼顾 gas 成本与可用性，对文本字段做“适中”限制：

- `name`：
  
  - 建议最大长度：**64 字节**（约 64 个 ASCII 字符，或更少的多字节字符）；
  
  - 合约可使用 `bytes(name).length <= 64` 进行检查。

- `description`：
  
  - 建议最大长度：**512 字节**；
  
  - 合约使用 `bytes(description).length <= 512` 检查。

- `avatarCid` / `tokenUri`：
  
  - 不在合约中严格限制长度（通常 IPFS CID + 协议前缀在几十字节左右），可在前端做校验。

编码方面：

- 不强制链上检查 UTF-8；

- 假定前端传入为 UTF-8 字符串；

- 文档中注明“前端应确保字符串编码为 UTF-8”。

### 4.3 事件设计（不做超细粒度）

- 事件列表（建议）：
  
  1. `event ProfileMinted(address indexed owner, uint256 indexed tokenId);`
  
  2. `event ProfileUpdated(address indexed operator, uint256 indexed tokenId);`
  
  3. `event ProfileBurned(address indexed operator, uint256 indexed tokenId);`
  
  4. `event DefaultAvatarCidSet(string cid);`
  
  5. `event UpgradeDisabled();`

- 不再拆分 `NameUpdated`, `DescriptionUpdated`, `AvatarUpdated`，减少事件数量和复杂度。

---

## 5. 存储结构与内部设计

### 5.1 Profile 结构体（v1 仅核心字段）

```solidity
struct Profile {
    string name;         // 昵称
    string description;  // 个人简介
    string avatarCid;    // 头像图片的 IPFS CID（不带前缀）
    uint64 createdAt;    // 创建时间
    uint64 updatedAt;    // 最近更新时间
}
```

- 映射：
  
  ```solidity
  mapping(uint256 => Profile) private _profiles;
  ```

- v1 不包含其他字段（如 twitter / tags / theme），留作后续 UUPS 升级时追加。

### 5.2 tokenURI 存储

两种可选具体实现方式（写在实现文档里即可）：

1. 使用 `ERC721URIStorageUpgradeable`：
   
   - 直接调用 `_setTokenURI(tokenId, tokenUri)`；
   
   - 重写多继承下的 `tokenURI` 与 `supportsInterface`。

2. 自行维护 `_tokenURIs` 映射：
   
   ```solidity
   mapping(uint256 => string) private _tokenURIs;
   
   function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
      require(_exists(tokenId), "URI set of nonexistent token");
      _tokenURIs[tokenId] = _tokenURI;
   }
   
   function tokenURI(uint256 tokenId)
      public
      view
      override
      returns (string memory)
   {
      require(_exists(tokenId), "URI query for nonexistent token");
      return _tokenURIs[tokenId];
   }
   ```
- 最终选哪一种可以在实现阶段决定，但需求上只要求“链上可维护每个 token 的 tokenURI”。

---

## 6. 合约接口概览（v1）

### 6.1 对外公开函数（external）

1. **初始化**
   
   - `function initialize(string calldata name_, string calldata symbol_, string calldata defaultAvatarCid_) external initializer;`
     
     - 设定 ERC721 名称/符号；
     
     - 设置 `defaultAvatarCid`；
     
     - 初始化 owner（`__Ownable_init`）；
     
     - 初始化 UUPS（`__UUPSUpgradeable_init`）。

2. **mint Profile**
   
   - `mintProfile(name, description, useDefaultAvatar, avatarCidOrEmpty, tokenUri) external returns (uint256 tokenId);`

3. **更新 Profile**
   
   - `updateProfile(tokenId, newName, newDescription, newAvatarCid, newTokenUri) external;`

4. **burn Profile**
   
   - `burnProfile(uint256 tokenId) external;`
     
     - 仅 `ownerOf(tokenId)` 或合约 owner 可调用；
     
     - 删除 `_profiles[tokenId]` 与 `_tokenURIs[tokenId]`；
     
     - 调用 `_burn(tokenId)`；
     
     - 触发 `ProfileBurned`。

5. **默认头像管理（owner）**
   
   - `setDefaultAvatarCid(string calldata cid) external onlyOwner;`
     
     - 更新 `defaultAvatarCid` 并触发 `DefaultAvatarCidSet` 事件。

6. **升级封印**
   
   - `disableUpgrade() external onlyOwner;`
     
     - 设置 `upgradeDisabled = true;`
     
     - 触发 `UpgradeDisabled`。

### 6.2 View 函数（public / external view）

1. `function getProfile(uint256 tokenId) external view returns (ProfileView memory);`
   
   - `ProfileView` 结构体例：
     
     ```solidity
     struct ProfileView {
        uint256 tokenId;
        address owner;
        string name;
        string description;
        string avatarCid;
        uint64 createdAt;
        uint64 updatedAt;
        string tokenUri;
     }
     ```

2. `function getProfilesOf(address user) external view returns (uint256[] memory tokenIds);`
   
   - 可通过遍历（不推荐 on-chain 大规模遍历）或配合 off-chain indexer；
   
   - v1 可以只提供简单工具函数，重度查询交给 off-chain。

3. `function hasProfile(address user) external view returns (bool);`
   
   - 简单场景下可以实现为 `balanceOf(user) > 0`。

4. 标准 ERC-721 view：
   
   - `balanceOf`, `ownerOf`, `name`, `symbol`, `tokenURI`, `supportsInterface` 等。

---

## 7. 安全性与升级策略

1. **Storage Layout**
   
   - 遵守 OZ upgradeable 合约的存储布局规则：
     
     - 不使用构造函数，改用 `initialize`；
     
     - v1 定义好状态变量顺序与数量；
     
     - v2 及之后只允许在尾部追加新变量（包括 Profile 新字段），不改变现有变量顺序。

2. **升级权限**
   
   - `_authorizeUpgrade` 只允许 `owner` 且 `upgradeDisabled == false`；
   
   - 推荐在部署后尽早把 owner 修改为更安全的钱包（如硬件钱包、多签）。

3. **封印升级**
   
   - 一旦调用 `disableUpgrade()`：
     
     - 未来任何 `upgradeTo`/`upgradeToAndCall` 调用都会被 `_authorizeUpgrade` 拒绝；
     
     - 合约逻辑与数据将永远固定。

---

## 8. 未来扩展预留（v2+）

在 v1 的基础上，未来可通过 UUPS 升级无缝添加：

- 在 `Profile` 结构体末尾追加字段：
  
  - 社交账号（twitter handle / telegram）；
  
  - 标签 / 权限等级 / KYC 状态；
  
  - 多皮肤主题标识（如 `bytes32 theme`）。

- 新的 view 函数：
  
  - 基于 tag / theme / level 的过滤查询；

- 新的管理逻辑：
  
  - 黑名单 / 冻结某些 Profile NFT 的更新权限等。

所有上述扩展均通过新实现合约 + `upgradeTo` 完成，不影响现有 v1 数据。


