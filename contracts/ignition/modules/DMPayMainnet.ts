import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MAINNET_ENS_REGISTRY = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e";
const MAINNET_ENS_RESOLVER = "0xF29100983E058B709F3D539b0c765937B804AC15";
const MAINNET_USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const DMPAY_ETH_NAMEHASH = "0x2059bd34c28c7a6645dd35be7e5dcc4b3e4999849bbe8b2c8b838f2d4cfc3ec8";

const DMPayMainnetModule = buildModule("DMPayMainnetModule", (m) => {
  const registry = m.contract("DMPayRegistry", [
    DMPAY_ETH_NAMEHASH,
    MAINNET_ENS_REGISTRY,
    MAINNET_ENS_RESOLVER,
  ]);

  const messaging = m.contract("DMPayMessaging", [
    MAINNET_USDC,
    registry,
  ]);

  return { registry, messaging };
});

export default DMPayMainnetModule;
