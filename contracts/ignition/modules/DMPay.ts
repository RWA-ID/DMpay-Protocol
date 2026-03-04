import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const SEPOLIA_ENS_REGISTRY = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e";
const SEPOLIA_USDC = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238";
const DMPAY_ETH_NAMEHASH = "0x2059bd34c28c7a6645dd35be7e5dcc4b3e4999849bbe8b2c8b838f2d4cfc3ec8";

const DMPayModule = buildModule("DMPayModule", (m) => {
  const registry = m.contract("DMPayRegistry", [
    DMPAY_ETH_NAMEHASH,
    SEPOLIA_ENS_REGISTRY,
  ]);

  const messaging = m.contract("DMPayMessaging", [
    SEPOLIA_USDC,
    registry,
  ]);

  return { registry, messaging };
});

export default DMPayModule;
