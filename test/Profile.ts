import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";
import { encodeFunctionData } from "viem";

async function deployProfile() {
  const { viem } = await network.connect();

  const [ownerClient, userClient, otherClient] =
    await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();

  // 1. 部署实现合约 UniChatProfile（逻辑合约）
  const impl = await viem.deployContract("UniChatProfile");

  // 2. 编码 initialize(...) 的 calldata，给 Proxy 构造函数的 _data 用
  //    等价于 solidity 里的 abi.encodeWithSelector(...)
  const initData = encodeFunctionData({
    abi: impl.abi,
    functionName: "initialize",
    args: [
      "UniChat Profile",                // name_
      "UCHP",                           // symbol_
      "QmDefaultAvatarCid_XXXX",        // defaultAvatarCid_
      ownerClient.account.address,      // initialOwner
    ],
  });

  // 3. 部署 ERC1967Proxy(impl, initData)
  const proxy = await viem.deployContract("ERC1967Proxy", [
    impl.address,
    initData,
  ]);

  // 4. 用 UniChatProfile 的 ABI 绑定到 proxy 地址
  const profile = await viem.getContractAt(
    "UniChatProfile",
    proxy.address
  );

  return {
    impl,
    proxy,
    profile,
    ownerClient,
    userClient,
    otherClient,
    publicClient,
  };
}

describe("UniChatProfile (UUPS via ERC1967Proxy)", () => {
  it("mintProfile: 使用默认头像成功铸造 NFT", async () => {
    const { profile, userClient, publicClient } = await deployProfile();

    const txHash = await profile.write.mintProfile(
      [
        "Huahua",                          // name
        "BSC/Arb UniChat builder",         // description
        true,                              // useDefaultAvatar
        "",                                // avatarCidOrEmpty
        "ipfs://QmMetadataCid_123",        // tokenUri
      ],
      {
        account: userClient.account,       // msg.sender
      }
    );

    await publicClient.waitForTransactionReceipt({ hash: txHash });

    // v1 里我们约定 tokenId 从 1 开始
    const view = await profile.read.getProfile([1n]);

    assert.equal(view.tokenId, 1n);
    assert.equal(
      view.owner.toLowerCase(),
      userClient.account.address.toLowerCase()
    );
    assert.equal(view.name, "Huahua");
    assert.equal(view.description, "BSC/Arb UniChat builder");
    // 头像应该是默认头像
    assert.equal(view.avatarCid, "QmDefaultAvatarCid_XXXX");
  });

  it("updateProfile: 只修改 description，不影响 name", async () => {
    const { profile, userClient, publicClient } = await deployProfile();

    // 先 mint
    const mintHash = await profile.write.mintProfile(
      [
        "Huahua",
        "old description",
        true,
        "",
        "ipfs://QmMetadataCid_123",
      ],
      { account: userClient.account }
    );
    await publicClient.waitForTransactionReceipt({ hash: mintHash });

    // 再只改 description
    const updateHash = await profile.write.updateProfile(
      [
        1n,                 // tokenId
        "",                 // newName (空串 = 不改)
        "new description",  // newDescription
        "",                 // newAvatarCid
        "",                 // newTokenUri
      ],
      { account: userClient.account }
    );
    await publicClient.waitForTransactionReceipt({ hash: updateHash });

    const view = await profile.read.getProfile([1n]);
    assert.equal(view.name, "Huahua");
    assert.equal(view.description, "new description");
  });

  it("burnProfile: 销毁后 hasProfile==false", async () => {
    const { profile, userClient, publicClient } = await deployProfile();

    const mintHash = await profile.write.mintProfile(
      [
        "Huahua",
        "desc",
        true,
        "",
        "ipfs://QmMetadataCid_123",
      ],
      { account: userClient.account }
    );
    await publicClient.waitForTransactionReceipt({ hash: mintHash });

    const hasBefore = await profile.read.hasProfile([
      userClient.account.address,
    ]);
    assert.equal(hasBefore, true);

    const burnHash = await profile.write.burnProfile([1n], {
      account: userClient.account,
    });
    await publicClient.waitForTransactionReceipt({ hash: burnHash });

    const hasAfter = await profile.read.hasProfile([
      userClient.account.address,
    ]);
    assert.equal(hasAfter, false);
  });
});
