const { deployProxy, upgradeProxy } = require("@openzeppelin/truffle-upgrades");

// V1 contracts (non-upgradeable, original deployment)
const Metablox = artifacts.require("v1/Metablox");

// Proxy demo contracts (UUPS upgradeable)
const BoxV1 = artifacts.require("proxy-demo/BoxV1");
const BoxV2 = artifacts.require("proxy-demo/BoxV2");

module.exports = async function (deployer) {
  // ─── V1 Deployment (traditional, non-upgradeable) ───────────────────
  // This is how the original Metablox contract was deployed:
  //   await deployer.deploy(Metablox, 1000); // total supply of 1000

  // ─── Proxy Demo: UUPS Upgradeable Deployment ───────────────────────
  // Step 1: Deploy BoxV1 behind a UUPS proxy
  //   The deployProxy function:
  //   1. Deploys the BoxV1 implementation contract
  //   2. Deploys an ERC1967 proxy contract
  //   3. Calls initialize(42) on the proxy (which delegates to BoxV1)
  const box = await deployProxy(BoxV1, [42], {
    deployer,
    kind: "uups",
  });
  console.log("BoxV1 proxy deployed at:", box.address);

  // Step 2: Upgrade the proxy to BoxV2
  //   The upgradeProxy function:
  //   1. Deploys the BoxV2 implementation contract
  //   2. Calls upgradeTo(BoxV2_address) on the proxy
  //   3. Now all calls through the proxy use BoxV2 logic
  //   4. The stored value (42) is preserved — storage lives in the proxy
  const upgraded = await upgradeProxy(box.address, BoxV2, { deployer });
  console.log("Upgraded to BoxV2 at:", upgraded.address);

  // Verify: the value set via BoxV1 is still accessible via BoxV2
  const value = await upgraded.retrieve();
  console.log("Value after upgrade:", value.toString()); // Should print 42

  // New V2 function: increment
  await upgraded.increment();
  const newValue = await upgraded.retrieve();
  console.log("Value after increment:", newValue.toString()); // Should print 43
};
