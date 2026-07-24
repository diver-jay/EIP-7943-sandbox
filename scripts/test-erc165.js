const hre = require("hardhat");

async function checkERC165(contractAddress, contractName) {
  console.log(`\n--- Checking IERC165 interface support for ${contractName} (${contractAddress}) ---`);

  // Interface IDs
  const IERC165_ID = "0x01ffc9a7";

  // Calculate EIP-7943 interface IDs dynamically or using known selectors
  const ierc7943FungibleInterface = new hre.ethers.Interface([
    "function forcedTransfer(address from, address to, uint256 amount) external",
    "function getFrozenTokens(address account) external view returns (uint256)",
    "function setFrozenTokens(address account, uint256 amount) external",
    "function canTransact(address account) external view returns (bool)",
    "function canTransfer(address from, address to, uint256 amount) external view returns (bool)",
  ]);

  let erc7943FungibleId = 0n;
  ierc7943FungibleInterface.forEachFunction((func) => {
    erc7943FungibleId = erc7943FungibleId ^ BigInt(func.selector);
  });
  const IERC7943_FUNGIBLE_ID = "0x" + erc7943FungibleId.toString(16).padStart(8, "0");

  const ContractFactory = await hre.ethers.getContractFactory(contractName);
  const contract = ContractFactory.attach(contractAddress);

  try {
    const supports165 = await contract.supportsInterface(IERC165_ID);
    console.log(`[IERC165] (${IERC165_ID}):`, supports165 ? "✅ Supported" : "❌ Not Supported");
  } catch (err) {
    console.log(`[IERC165] error checking:`, err.message);
  }

  try {
    const supports7943 = await contract.supportsInterface(IERC7943_FUNGIBLE_ID);
    console.log(`[IERC7943Fungible] (${IERC7943_FUNGIBLE_ID}):`, supports7943 ? "✅ Supported" : "❌ Not Supported");
  } catch (err) {
    console.log(`[IERC7943Fungible] error checking:`, err.message);
  }
}

async function main() {
  const erc20Address = process.env.CONTRACT_ADDRESS;
  if (!erc20Address) {
    console.log("Usage: CONTRACT_ADDRESS=<deployed_address> npx hardhat run scripts/test-erc165.js --network <network>");
    process.exit(1);
  }

  await checkERC165(erc20Address, "ERC20uRWA");
}

main().catch((error) => {
  console.error("Test failed:", error);
  process.exitCode = 1;
});
