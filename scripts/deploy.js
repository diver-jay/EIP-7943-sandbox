const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("==================================================");
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());
  console.log("==================================================");

  // 1. Deploy ComplianceRegistry
  console.log("\n1. Deploying ComplianceRegistry...");
  const ComplianceRegistry = await hre.ethers.getContractFactory("ComplianceRegistry");
  const registry = await ComplianceRegistry.deploy();
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log("-> ComplianceRegistry deployed to:", registryAddress);

  // 2. Deploy ERC20uRWA (Fungible Token)
  console.log("\n2. Deploying ERC20uRWA (Fungible Token)...");
  const ERC20uRWA = await hre.ethers.getContractFactory("ERC20uRWA");
  const erc20 = await ERC20uRWA.deploy(
    "Real World Asset Token",
    "uRWA-20",
    deployer.address,
    registryAddress
  );
  await erc20.waitForDeployment();
  const erc20Address = await erc20.getAddress();
  console.log("-> ERC20uRWA deployed to:", erc20Address);

  // 3. Deploy ERC721uRWA (Non-Fungible Token)
  console.log("\n3. Deploying ERC721uRWA (Non-Fungible Token)...");
  const ERC721uRWA = await hre.ethers.getContractFactory("ERC721uRWA");
  const erc721 = await ERC721uRWA.deploy(
    "Real World Asset NFT",
    "uRWA-721",
    deployer.address,
    registryAddress
  );
  await erc721.waitForDeployment();
  const erc721Address = await erc721.getAddress();
  console.log("-> ERC721uRWA deployed to:", erc721Address);

  // 4. Deploy ERC1155uRWA (Multi-Token)
  console.log("\n4. Deploying ERC1155uRWA (Multi-Token)...");
  const ERC1155uRWA = await hre.ethers.getContractFactory("ERC1155uRWA");
  const erc1155 = await ERC1155uRWA.deploy(
    "https://api.example.com/metadata/{id}.json",
    deployer.address,
    registryAddress
  );
  await erc1155.waitForDeployment();
  const erc1155Address = await erc1155.getAddress();
  console.log("-> ERC1155uRWA deployed to:", erc1155Address);

  console.log("\n==================================================");
  console.log("Deployment complete!");
  console.log("Registry Address:", registryAddress);
  console.log("ERC20uRWA Address:", erc20Address);
  console.log("ERC721uRWA Address:", erc721Address);
  console.log("ERC1155uRWA Address:", erc1155Address);
  console.log("==================================================");
}

main().catch((error) => {
  console.error("Deployment failed:", error);
  process.exitCode = 1;
});
