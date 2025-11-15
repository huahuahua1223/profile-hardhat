// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// OpenZeppelin Upgradeable 基类
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";

// UniChat 接口
import {IUniChatProfile} from "./IUniChatProfile.sol";

/// @title UniChatProfile - 可转让 & 可升级的用户资料头像 NFT
/// @notice
/// - 每张 NFT 代表一张“资料卡”
/// - 可在地址之间自由转移（非 SBT）
/// - 链上存 name/description/avatarCid/timestamps
/// - 同时存 tokenURI，指向 JSON metadata（通常在 IPFS 上）
/// - 使用 UUPS 模式可升级，并支持一次性封印升级
contract UniChatProfile is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IUniChatProfile
{
    // ======== Storage ========

    /// @notice Profile 主存储：tokenId => Profile
    mapping(uint256 => Profile) private _profiles;

    /// @notice 下一个要分配的 tokenId，从 1 开始自增
    uint256 private _nextTokenId;

    /// @notice 全局默认头像 CID
    string private _defaultAvatarCid;

    /// @notice 是否已经封印升级
    bool private _upgradeDisabled;

    // ======== Upgradeable 模式推荐的构造函数写法 ========

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // 禁用实现合约的初始化，防止被直接使用
        _disableInitializers();
    }

    // ======== 初始化函数 ========

    /// @notice 初始化函数，只能被调用一次（通过 Proxy 调用）
    /// @param name_ ERC721 名称
    /// @param symbol_ ERC721 符号
    /// @param defaultAvatarCid_ 初始默认头像 CID
    /// @param initialOwner 初始 owner 地址（升级权限 & 管理权限）
    function initialize(
        string calldata name_,
        string calldata symbol_,
        string calldata defaultAvatarCid_,
        address initialOwner
    ) external initializer {
        __ERC721_init(name_, symbol_);
        __ERC721URIStorage_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        require(bytes(defaultAvatarCid_).length != 0, "Default avatar CID empty");
        _defaultAvatarCid = defaultAvatarCid_;

        // 从 1 开始分配 tokenId，0 作为“未初始化/无效”保留
        _nextTokenId = 1;
        _upgradeDisabled = false;
    }

    // ======== 外部可调用函数：铸造 / 更新 / 默认头像 / 销毁 ========

    /// @inheritdoc IUniChatProfile
    function mintProfile(
        string calldata name,
        string calldata description,
        bool useDefaultAvatarFlag,
        string calldata avatarCidOrEmpty,
        string calldata tokenUri
    ) external override returns (uint256 tokenId) {
        address sender = msg.sender;

        _validateName(name);
        _validateDescription(description);

        string memory avatarCid_;
        if (useDefaultAvatarFlag) {
            avatarCid_ = _defaultAvatarCid;
        } else {
            require(bytes(avatarCidOrEmpty).length != 0, "Avatar CID required");
            avatarCid_ = avatarCidOrEmpty;
        }

        require(bytes(tokenUri).length != 0, "tokenURI required");

        tokenId = _nextTokenId;
        _nextTokenId = tokenId + 1;

        uint64 ts = uint64(block.timestamp);

        _profiles[tokenId] = Profile({
            name: name,
            description: description,
            avatarCid: avatarCid_,
            createdAt: ts,
            updatedAt: ts
        });

        // 为调用者自己铸造
        _safeMint(sender, tokenId);

        // 存储 tokenURI（通常为 ipfs://...）
        _setTokenURI(tokenId, tokenUri);

        emit ProfileMinted(sender, tokenId);
    }

    /// @inheritdoc IUniChatProfile
    function updateProfile(
        uint256 tokenId,
        string calldata newName,
        string calldata newDescription,
        string calldata newAvatarCid,
        string calldata newTokenUri
    ) external override {
        _requireProfileExists(tokenId);

        address ownerOfToken = ownerOf(tokenId);
        // token 拥有者或合约 owner 才可更新
        require(
            msg.sender == ownerOfToken || msg.sender == owner(),
            "Not owner nor contract owner"
        );

        Profile storage p = _profiles[tokenId];
        bool changed = false;

        // 昵称
        if (bytes(newName).length != 0) {
            _validateName(newName);
            p.name = newName;
            changed = true;
        }

        // 简介
        if (bytes(newDescription).length != 0) {
            _validateDescription(newDescription);
            p.description = newDescription;
            changed = true;
        }

        // 头像 CID
        if (bytes(newAvatarCid).length != 0) {
            p.avatarCid = newAvatarCid;
            changed = true;
        }

        // tokenURI
        if (bytes(newTokenUri).length != 0) {
            _setTokenURI(tokenId, newTokenUri);
            changed = true;
        }

        if (changed) {
            p.updatedAt = uint64(block.timestamp);
            emit ProfileUpdated(msg.sender, tokenId);
        }
    }

    /// @inheritdoc IUniChatProfile
    function useDefaultAvatar(uint256 tokenId) external override {
        _requireProfileExists(tokenId);

        address ownerOfToken = ownerOf(tokenId);
        require(
            msg.sender == ownerOfToken || msg.sender == owner(),
            "Not owner nor contract owner"
        );

        Profile storage p = _profiles[tokenId];
        p.avatarCid = _defaultAvatarCid;
        p.updatedAt = uint64(block.timestamp);

        emit ProfileUpdated(msg.sender, tokenId);
    }

    /// @inheritdoc IUniChatProfile
    function burnProfile(uint256 tokenId) external override {
        _requireProfileExists(tokenId);

        address ownerOfToken = ownerOf(tokenId);
        require(
            msg.sender == ownerOfToken || msg.sender == owner(),
            "Not owner nor contract owner"
        );

        delete _profiles[tokenId];

        _burn(tokenId);

        emit ProfileBurned(msg.sender, tokenId);
    }

    /// @inheritdoc IUniChatProfile
    function setDefaultAvatarCid(string calldata cid) external override onlyOwner {
        require(bytes(cid).length != 0, "Empty CID");
        _defaultAvatarCid = cid;
        emit DefaultAvatarCidSet(cid);
    }

    /// @inheritdoc IUniChatProfile
    function disableUpgrade() external override onlyOwner {
        require(!_upgradeDisabled, "Already disabled");
        _upgradeDisabled = true;
        emit UpgradeDisabled();
    }

    // ======== View 接口实现 ========

    /// @inheritdoc IUniChatProfile
    function getProfile(uint256 tokenId)
        external
        view
        override
        returns (ProfileView memory)
    {
        _requireProfileExists(tokenId);

        Profile storage p = _profiles[tokenId];

        return ProfileView({
            tokenId: tokenId,
            owner: ownerOf(tokenId),
            name: p.name,
            description: p.description,
            avatarCid: p.avatarCid,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
            tokenUri: tokenURI(tokenId)
        });
    }

    /// @inheritdoc IUniChatProfile
    function getProfilesOf(address user)
        external
        view
        override
        returns (uint256[] memory)
    {
        uint256 balance = balanceOf(user);
        uint256[] memory result = new uint256[](balance);

        if (balance == 0) {
            return result;
        }

        uint256 supply = _nextTokenId - 1;
        uint256 count;

        // 简单遍历所有 tokenId，直到找到该地址名下的所有 NFT
        for (uint256 tokenId = 1; tokenId <= supply && count < balance; tokenId++) {
            if (_ownerOf(tokenId) != address(0) && ownerOf(tokenId) == user) {
                result[count] = tokenId;
                count++;
            }
        }

        return result;
    }

    /// @inheritdoc IUniChatProfile
    function hasProfile(address user) external view override returns (bool) {
        return balanceOf(user) > 0;
    }

    /// @inheritdoc IUniChatProfile
    function defaultAvatarCid() external view override returns (string memory) {
        return _defaultAvatarCid;
    }

    /// @inheritdoc IUniChatProfile
    function upgradeDisabled() external view override returns (bool) {
        return _upgradeDisabled;
    }

    // ======== UUPS 升级授权 ========

    /// @dev UUPS 升级授权钩子：仅 owner 且尚未封印升级时允许
    function _authorizeUpgrade(address /* newImplementation */)
        internal
        override
        onlyOwner
    {
        require(!_upgradeDisabled, "Upgrade disabled");
        // newImplementation 不做额外校验，由 OZ Upgrades 插件在部署时完成安全检查
    }

    // ======== 内部工具函数 ========

    function _requireProfileExists(uint256 tokenId) internal view {
        require(_ownerOf(tokenId) != address(0), "Profile: nonexistent token");
    }

    function _validateName(string calldata name) internal pure {
        uint256 len = bytes(name).length;
        require(len > 0 && len <= 64, "Name length invalid");
    }

    function _validateDescription(string calldata description) internal pure {
        uint256 len = bytes(description).length;
        require(len <= 512, "Description too long");
    }

    // ======== 多继承需要的 override ========

    /// @dev ERC721 & ERC721URIStorage 的 tokenURI 冲突解决
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /// @dev supportsInterface 需要包含 ERC721URIStorageUpgradeable（实现 IERC4906）
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
