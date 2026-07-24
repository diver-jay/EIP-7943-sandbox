const { Wallet } = require("ethers");
const fs = require("fs");
const path = require("path");

async function main() {
  const wallet = Wallet.createRandom();

  console.log("==================================================");
  console.log("🆕 New Developer Wallet Created!");
  console.log("--------------------------------------------------");
  console.log("Public Address :", wallet.address);
  console.log("Private Key    :", wallet.privateKey);
  console.log("==================================================");

  const envPath = path.join(__dirname, "..", ".env");
  let envContent = "";

  if (fs.existsSync(envPath)) {
    envContent = fs.readFileSync(envPath, "utf8");
    if (envContent.includes("PRIVATE_KEY=")) {
      envContent = envContent.replace(/PRIVATE_KEY=.*/, `PRIVATE_KEY=${wallet.privateKey}`);
    } else {
      envContent += `\nPRIVATE_KEY=${wallet.privateKey}\n`;
    }
  } else {
    envContent = `SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/alch_oaRocOynAv8QdTCzMvKdh\nPRIVATE_KEY=${wallet.privateKey}\n`;
  }

  fs.writeFileSync(envPath, envContent, "utf8");
  console.log("\n✅ Private key automatically saved/updated in .env file!");
  console.log("\n💧 Next Step: Get free Sepolia ETH for gas fees");
  console.log("Copy your public address:", wallet.address);
  console.log("Claim testnet ETH from any of these Faucets:");
  console.log("  - Alchemy Faucet: https://www.alchemy.com/faucets/ethereum-sepolia");
  console.log("  - QuickNode Faucet: https://faucet.quicknode.com/drip");
  console.log("  - Google Cloud Faucet: https://cloud.google.com/application/web3/faucet/ethereum/sepolia");
  console.log("==================================================");
}

main().catch((error) => {
  console.error("Wallet creation failed:", error);
  process.exitCode = 1;
});
