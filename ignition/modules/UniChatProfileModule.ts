import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const UniChatProfileModule = buildModule("UniChatProfileModule", (m) => {
  // 1. 部署实现合约
  const impl = m.contract("UniChatProfile");

  // 2. 部署参数：默认头像 CID & 初始 owner
  const defaultAvatarCid = m.getParameter(
    "defaultAvatarCid",
    "QmDefaultAvatarCid........" // 默认值可以随便填一个，将来用 CLI 参数覆盖
  );

  const initialOwner = m.getAccount(0);

  // 3. 编码 initialize 调用
  const initData = m.encodeFunctionCall(impl, "initialize", [
    "UniChat Profile",
    "UCHP",
    defaultAvatarCid,
    initialOwner,
  ]);

  // 4. 部署 ERC1967Proxy，并指向实现合约 + 执行初始化
  // constructor(address _logic, bytes memory _data)
  const proxy = m.contract("ERC1967Proxy", [impl, initData]);

  // 5. 把 proxy 地址当成 UniChatProfile ABI 来用（之后 read/write 都走 profile）
  const profile = m.contractAt("UniChatProfile", proxy, { id: "UniChatProfileProxy" });

  return { impl, proxy, profile };
});

export default UniChatProfileModule;
