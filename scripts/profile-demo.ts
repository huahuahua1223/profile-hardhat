import { network } from "hardhat";
import UniChatProfileModule from "../ignition/modules/UniChatProfileModule.js";

async function main() {
  // 1. 连接当前 network，拿到 ignition + viem client
  const { ignition, viem } = await network.connect();

  const [deployerClient, userClient] = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();

  console.log("Deployer:", deployerClient.account.address);
  console.log("User:", userClient.account.address);

  // 2. 部署（或复用已有）UniChatProfileModule
  const { profile } = await ignition.deploy(UniChatProfileModule, {
    parameters: {
      UniChatProfileModule: {
        defaultAvatarCid: "QmDefaultAvatarCidFromScript........",
      },
    },
  });

  console.log("Profile proxy address:", profile.address);

  // 3. User 铸造一张新的 Profile NFT
  const mintHash = await profile.write.mintProfile(
    [
      "Huahua",                              // name
      "BSC/Arb multi-chain UniChat builder", // description
      true,                                  // useDefaultAvatar
      "",                                    // avatarCidOrEmpty
      "ipfs://QmYourMetadataJsonCid........" // tokenURI
    ],
    {
      account: userClient.account, // msg.sender
    }
  );

  console.log("mint tx hash:", mintHash);
  await publicClient.waitForTransactionReceipt({ hash: mintHash });

  // 4. 假设第一个 tokenId = 1，读一下 Profile
  const profileView = await profile.read.getProfile([1n]);
  console.log("Profile[1]:", profileView);

  // 5. 更新 description（只改这个字段，其他字段传空串）
  const updateHash = await profile.write.updateProfile(
    [
      1n,                  // tokenId
      "",                  // newName (空串 = 不修改)
      "Updated bio v1.0",  // newDescription
      "",                  // newAvatarCid
      "",                  // newTokenUri
    ],
    {
      account: userClient.account,
    }
  );

  console.log("update tx hash:", updateHash);
  await publicClient.waitForTransactionReceipt({ hash: updateHash });

  const updated = await profile.read.getProfile([1n]);
  console.log("Updated Profile[1]:", updated);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });