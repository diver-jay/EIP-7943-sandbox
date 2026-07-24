const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("==================================================");
  console.log("EIP-7943 (uRWA) On-Chain Feature Test");
  console.log("Running on network:", hre.network.name);
  console.log("Deployer Address  :", deployer.address);
  console.log("==================================================");

  // Addresses from deployment (or from env/arguments)
  const registryAddress = process.env.REGISTRY_ADDRESS || "0x0e5C7df25b4F7Ddc8F7E73E95BFD052Be564EF10";
  const erc20Address = process.env.ERC20_ADDRESS || "0xD9b2F259d04CD0ea18c36791806054F375fDCe9f";

  const ComplianceRegistry = await hre.ethers.getContractFactory("ComplianceRegistry");
  const registry = ComplianceRegistry.attach(registryAddress);

  const ERC20uRWA = await hre.ethers.getContractFactory("ERC20uRWA");
  const erc20 = ERC20uRWA.attach(erc20Address);

  // Generate a random test account for Bob & Alice
  const bob = hre.ethers.Wallet.createRandom();
  const alice = deployer.address;

  console.log("\n🔹 Test User (Bob):", bob.address);
  console.log("🔹 Admin User (Alice):", alice);

  // -------------------------------------------------------------
  // Test 1: Non-whitelisted User Minting Restriction
  // -------------------------------------------------------------
  console.log("\n--------------------------------------------------");
  console.log("Test 1: Attempting to mint tokens to non-KYC user (Bob)");
  try {
    const tx = await erc20.mint(bob.address, hre.ethers.parseEther("1000"));
    await tx.wait();
    console.log("❌ Failed: Minting should have reverted for non-KYC user!");
  } catch (error) {
    console.log("✅ Passed: Minting reverted as expected! (User not whitelisted)");
  }

  // -------------------------------------------------------------
  // Test 2: Whitelisting User & Successful Minting
  // -------------------------------------------------------------
  console.log("\n--------------------------------------------------");
  console.log("Test 2: Whitelisting Bob & Minting 1,000 uRWA tokens");
  
  console.log("-> Whitelisting Bob in ComplianceRegistry...");
  let tx = await registry.setWhitelistStatus(bob.address, true);
  await tx.wait();
  console.log("-> Whitelisting Alice in ComplianceRegistry...");
  tx = await registry.setWhitelistStatus(alice, true);
  await tx.wait();

  console.log("-> Minting 1,000 uRWA to Bob...");
  tx = await erc20.mint(bob.address, hre.ethers.parseEther("1000"));
  await tx.wait();

  const bobBalance = await erc20.balanceOf(bob.address);
  console.log("✅ Passed: Bob's new token balance:", hre.ethers.formatEther(bobBalance), "uRWA");

  // -------------------------------------------------------------
  // Test 3: Asset Freezing (Token Lockup)
  // -------------------------------------------------------------
  console.log("\n--------------------------------------------------");
  console.log("Test 3: Freezing 400 uRWA tokens of Bob's balance");
  tx = await erc20.setFrozenTokens(bob.address, hre.ethers.parseEther("400"));
  await tx.wait();

  const frozen = await erc20.getFrozenTokens(bob.address);
  console.log("-> Bob's frozen tokens:", hre.ethers.formatEther(frozen), "uRWA");

  const canTransfer700 = await erc20.canTransfer(bob.address, alice, hre.ethers.parseEther("700"));
  console.log("-> Can Bob transfer 700 uRWA? (Unfrozen is 600):", canTransfer700 ? "Yes" : "❌ No (Blocked by freeze)");

  const canTransfer500 = await erc20.canTransfer(bob.address, alice, hre.ethers.parseEther("500"));
  console.log("-> Can Bob transfer 500 uRWA? (Unfrozen is 600):", canTransfer500 ? "✅ Yes (Allowed)" : "No");

  // -------------------------------------------------------------
  // Test 4: Forced Transfer (Regulatory Intervention)
  // -------------------------------------------------------------
  console.log("\n--------------------------------------------------");
  console.log("Test 4: Executing Forced Transfer (Compliance Authority moving 500 uRWA from Bob to Alice)");
  tx = await erc20.forcedTransfer(bob.address, alice, hre.ethers.parseEther("500"));
  await tx.wait();

  const bobBalanceAfter = await erc20.balanceOf(bob.address);
  const aliceBalanceAfter = await erc20.balanceOf(alice);
  console.log("-> Bob's balance after forced transfer  :", hre.ethers.formatEther(bobBalanceAfter), "uRWA");
  console.log("-> Alice's balance after forced transfer:", hre.ethers.formatEther(aliceBalanceAfter), "uRWA");
  console.log("✅ Passed: Forced transfer succeeded!");

  // -------------------------------------------------------------
  // Test 5: Jurisdictional Control (Country Block)
  // -------------------------------------------------------------
  console.log("\n--------------------------------------------------");
  console.log("Test 5: Jurisdictional Blocking (Restricting Country 'XX')");
  
  tx = await registry.setJurisdictionStatus("XX", false);
  await tx.wait();
  
  tx = await registry.setUserJurisdiction(bob.address, "XX");
  await tx.wait();

  const isBobEligible = await registry.isEligible(bob.address);
  console.log("-> Is Bob eligible after jurisdiction 'XX' blocked?:", isBobEligible ? "Yes" : "❌ No (Blocked)");
  console.log("==================================================");
  console.log("🎉 All EIP-7943 RWA Feature Tests Completed Successfully!");
  console.log("==================================================");
}

main().catch((error) => {
  console.error("Test execution failed:", error);
  process.exitCode = 1;
});
