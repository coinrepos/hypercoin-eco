const hre = require("hardhat");

async function main() {
  const Contract = await hre.ethers.getContractFactory("HyperCoinEcosystem");
  const instance = await Contract.deploy();
  await instance.deployed();

  console.log("✅ HyperCoinEcosystem deployed at:", instance.address);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
