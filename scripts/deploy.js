const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  console.log("---------- Deploying to chain %d ----------", network.config.chainId);
  const StakingPoolActionsFactory = await ethers.getContractFactory("StakingPoolActions");
  const vTokenFactory = await ethers.getContractFactory("vToken");
  const SpecialStakingPoolFactory = await ethers.getContractFactory("SpecialStakingPool");
  const TokenSaleCreatorFactory = await ethers.getContractFactory("TokenSaleCreator");

  let stakingPoolActions = await StakingPoolActionsFactory.deploy(ethers.utils.parseEther("0.0003"));
  stakingPoolActions = await stakingPoolActions.deployed();

  let vToken = await vTokenFactory.deploy("vBitcoin", "vBTC", ethers.utils.parseEther("300000000"), "0xb69DB7b7B3aD64d53126DCD1f4D5fBDaea4fF578", 3);
  vToken = await vToken.deployed();

  let vToken2 = await vTokenFactory.deploy(
    "vBitraiser",
    "vBTR",
    ethers.utils.parseEther("300000000"),
    "0xb69DB7b7B3aD64d53126DCD1f4D5fBDaea4fF578",
    3
  );
  vToken2 = await vToken2.deployed();

  let specialStakingPool = await SpecialStakingPoolFactory.deploy(
    "0xb69DB7b7B3aD64d53126DCD1f4D5fBDaea4fF578",
    vToken.address,
    vToken2.address,
    20,
    10
  );
  specialStakingPool = await specialStakingPool.deployed();

  let tokenSaleCreator = await TokenSaleCreatorFactory.deploy(30);
  tokenSaleCreator = await tokenSaleCreator.deployed();

  const location = path.join(__dirname, "../addresses.json");
  const fileExists = fs.existsSync(location);

  if (fileExists) {
    const contentBuf = fs.readFileSync(location);
    let contentJSON = JSON.parse(contentBuf.toString());
    contentJSON = {
      ...contentJSON,
      [network.config.chainId]: {
        stakingPoolActions: stakingPoolActions.address,
        vBTC: vToken.address,
        vBTR: vToken2.address,
        specialStakingPool: specialStakingPool.address,
        tokenSaleCreator: tokenSaleCreator.address
      }
    };
    fs.writeFileSync(location, JSON.stringify(contentJSON, undefined, 2));
  } else {
    fs.writeFileSync(
      location,
      JSON.stringify(
        {
          [network.config.chainId]: {
            stakingPoolActions: stakingPoolActions.address,
            vBTC: vToken.address,
            vBTR: vToken2.address,
            specialStakingPool: specialStakingPool.address,
            tokenSaleCreator: tokenSaleCreator.address
          }
        },
        undefined,
        2
      )
    );
  }
})();
