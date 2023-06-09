import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import { ethers } from "hardhat";

async function main() {
  const owner = "0x6788b5bf9755b3b100af0f23df4781beff51779a";
  const beneficiary = "0x1f36664a18F1B50963CabbA8F9e7D03AD57532dD";

  const AdmodConsumer = await ethers.getContractFactory("AdmodConsumer");
  const admodConsumer = await AdmodConsumer.deploy(owner, beneficiary);

  await admodConsumer.deployed();

  console.log(`Contract deployed to ${admodConsumer.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
