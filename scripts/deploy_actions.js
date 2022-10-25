const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  console.log("---------- Deploying to chain %d ----------", network.config.chainId);
  const StakingPoolActionsFactory = await ethers.getContractFactory("StakingPoolActions");

  let stakingPoolActions = await StakingPoolActionsFactory.deploy(ethers.utils.parseEther("0.0003"));
  stakingPoolActions = await stakingPoolActions.deployed();

  const location = path.join(__dirname, "../staking_pool_actions_addresses.json");
  const fileExists = fs.existsSync(location);

  if (fileExists) {
    const contentBuf = fs.readFileSync(location);
    let contentJSON = JSON.parse(contentBuf.toString());
    contentJSON = {
      ...contentJSON,
      [network.config.chainId]: stakingPoolActions.address
    };
    fs.writeFileSync(location, JSON.stringify(contentJSON, undefined, 2));
  } else {
    fs.writeFileSync(
      location,
      JSON.stringify(
        {
          [network.config.chainId]: stakingPoolActions.address
        },
        undefined,
        2
      )
    );
  }
})();
