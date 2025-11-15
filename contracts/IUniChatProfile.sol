// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title UniChat Profile Interface
/// @notice 定义 UniChat 头像资料 NFT 的基础结构体、事件和外部接口
interface IUniChatProfile {
    // ======== Structs ========

    /// @notice 存储在链上的基础资料（不含 owner / tokenURI）
    struct Profile {
        string name;         // 昵称
        string description;  // 个人简介
        string avatarCid;    // 头像图片 IPFS CID（不带协议前缀）
        uint64 createdAt;    // 创建时间戳
        uint64 updatedAt;    // 最近更新时间戳
    }

    /// @notice 对外读取时返回的完整视图
    struct ProfileView {
        uint256 tokenId;
        address owner;
        string name;
        string description;
        string avatarCid;
        uint64 createdAt;
        uint64 updatedAt;
        string tokenUri;     // ERC721 tokenURI（通常指向 JSON 元数据）
    }

    // ======== Events ========

    /// @notice 当某地址成功铸造一张新的资料卡 NFT
    event ProfileMinted(address indexed owner, uint256 indexed tokenId);

    /// @notice 当资料被更新（包括昵称、简介、头像、tokenURI 任一字段）
    event ProfileUpdated(address indexed operator, uint256 indexed tokenId);

    /// @notice 当某张资料卡被销毁
    event ProfileBurned(address indexed operator, uint256 indexed tokenId);

    /// @notice 默认头像 CID 被更新
    event DefaultAvatarCidSet(string cid);

    /// @notice 合约被永久关闭升级能力
    event UpgradeDisabled();

    // ======== Core Functions ========

    /// @notice 为调用者自己铸造一张新的资料卡 NFT
    /// @param name 昵称
    /// @param description 个人简介
    /// @param useDefaultAvatarFlag 是否使用默认头像 CID
    /// @param avatarCidOrEmpty 若不使用默认头像，则填入自定义头像 CID；若 useDefaultAvatarFlag=true 则应为空字符串
    /// @param tokenUri 对应的 JSON metadata 的 tokenURI（通常是 ipfs://CID）
    /// @return tokenId 新铸造的 NFT 的 tokenId
    function mintProfile(
        string calldata name,
        string calldata description,
        bool useDefaultAvatarFlag,
        string calldata avatarCidOrEmpty,
        string calldata tokenUri
    ) external returns (uint256 tokenId);

    /// @notice 更新资料（昵称 / 简介 / 头像 CID / tokenURI），空字符串表示“不修改该字段”
    /// @param tokenId 目标资料卡 tokenId
    /// @param newName 新昵称（若为空串则不修改）
    /// @param newDescription 新简介（若为空串则不修改）
    /// @param newAvatarCid 新头像 CID（若为空串则不修改）
    /// @param newTokenUri 新 tokenURI（若为空串则不修改）
    function updateProfile(
        uint256 tokenId,
        string calldata newName,
        string calldata newDescription,
        string calldata newAvatarCid,
        string calldata newTokenUri
    ) external;

    /// @notice 将某张资料卡的头像恢复为当前默认头像 CID
    /// @param tokenId 目标资料卡 tokenId
    function useDefaultAvatar(uint256 tokenId) external;

    /// @notice 销毁某张资料卡 NFT
    /// @dev 仅 token 拥有者或合约 owner 可以调用
    function burnProfile(uint256 tokenId) external;

    /// @notice 设置全局默认头像 CID
    /// @dev 仅合约 owner 可调用
    function setDefaultAvatarCid(string calldata cid) external;

    /// @notice 永久关闭合约后续升级能力（封印升级）
    /// @dev 仅合约 owner 可调用，且不可逆
    function disableUpgrade() external;

    // ======== View Functions ========

    /// @notice 读取某个 tokenId 对应的完整 Profile 视图
    function getProfile(uint256 tokenId) external view returns (ProfileView memory);

    /// @notice 读取某地址当前持有的所有 Profile NFT 的 tokenId 列表
    /// @dev 为简化实现，内部按 tokenId 从 1 遍历到当前 _nextTokenId-1，gas 较大，仅建议 off-chain 调用
    function getProfilesOf(address user) external view returns (uint256[] memory);

    /// @notice 某地址是否至少拥有一张 Profile NFT
    function hasProfile(address user) external view returns (bool);

    /// @notice 当前默认头像 CID
    function defaultAvatarCid() external view returns (string memory);

    /// @notice 合约是否已经被封印升级
    function upgradeDisabled() external view returns (bool);
}
