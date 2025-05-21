const hre = require("hardhat");

async function main() {
  console.log("Deploying contracts...");

  // Deploy StudyTimerToken (ERC20)
  const Token = await hre.ethers.getContractFactory("StudyTimerToken");
  const token = await Token.deploy();
  await token.deployed();
  console.log("StudyTimerToken deployed to:", token.address);

  // Deploy StudyBadgeNFT (NFT)
  const Badge = await hre.ethers.getContractFactory("StudyBadgeNFT");
  const badge = await Badge.deploy();
  await badge.deployed();
  console.log("StudyBadgeNFT deployed to:", badge.address);

  // Deploy Main DApp Contract
  const Timer = await hre.ethers.getContractFactory("DecentralizedStudyTimer");
  const timer = await Timer.deploy(token.address, badge.address);
  await timer.deployed();
  console.log("DecentralizedStudyTimer deployed to:", timer.address);
}

main().catch((error) => {
  console.error("Deployment failed:", error);
  process.exitCode = 1;
});
