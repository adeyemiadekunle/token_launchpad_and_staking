const { expect, use } = require("chai");
const { ethers, waffle } = require("hardhat");
const { time } = require("@openzeppelin/test-helpers");

use(waffle.solidity);

describe("Tests", () => {
  describe("Token Sale Creator", () => {
    /**
     * @type {import('ethers').Contract}
     */
    let tokenSaleCreator;

    /**
     * @type {import('ethers').Contract}
     */
    let erc20;

    before(async () => {
      const TokenSaleCreatorFactory = await ethers.getContractFactory("TokenSaleCreator");
      tokenSaleCreator = await TokenSaleCreatorFactory.deploy(30);
      tokenSaleCreator = await tokenSaleCreator.deployed();

      const ERC20Factory = await ethers.getContractFactory("TestERC20");
      erc20 = await ERC20Factory.deploy(ethers.utils.parseEther("1000"));
      erc20 = await erc20.deployed();
    });

    it("should allow initialization of token sale", async () => {
      const [, signer2, signer3] = await ethers.getSigners();
      await erc20.approve(tokenSaleCreator.address, ethers.utils.parseUnits("500", 18));
      await expect(
        tokenSaleCreator.initTokenSale(
          erc20.address,
          ethers.utils.parseEther("500"),
          ethers.utils.parseEther("1"),
          ethers.utils.parseEther("0.1"),
          ethers.utils.parseUnits("10", 18),
          ethers.utils.parseEther("0.01"),
          ethers.utils.parseEther("0.8"),
          Math.ceil(Date.now() / 1000) + 60 * 60 * 24,
          3,
          signer2.address,
          signer3.address
        )
      ).to.emit(tokenSaleCreator, "TokenSaleItemCreated");
    });

    it("should permit contributions", async () => {
      await time.increase(time.duration.hours(24));
      const [, , , signer4] = await ethers.getSigners();
      const saleId = await tokenSaleCreator.allTokenSales(0);
      await expect(await tokenSaleCreator.connect(signer4).contribute(saleId, { value: ethers.utils.parseEther("0.5") })).to.changeEtherBalance(
        tokenSaleCreator,
        ethers.utils.parseEther("0.5")
      );
    });

    it("should prevent withdrawal before sale has ended", async () => {
      const [, , , signer4] = await ethers.getSigners();
      const saleId = await tokenSaleCreator.allTokenSales(0);
      await expect(tokenSaleCreator.connect(signer4).normalWithdrawal(saleId)).to.be.revertedWith("sale_has_not_ended");
    });

    it("should allow withdrawal after sale has ended", async () => {
      await time.increase(time.duration.days(3));
      const [, , , signer4] = await ethers.getSigners();
      const saleId = await tokenSaleCreator.allTokenSales(0);
      const balance = await tokenSaleCreator.balance(saleId, signer4.address);
      await expect(() => tokenSaleCreator.connect(signer4).normalWithdrawal(saleId)).to.changeTokenBalance(erc20, signer4, balance);
    });
  });

  describe("Staking Pool", () => {
    /**
     * @type {import('ethers').Contract}
     */
    let stakingPool;

    /**
     * @type {import('ethers').Contract}
     */
    let erc201;

    /**
     * @type {import('ethers').Contract}
     */
    let erc202;

    before(async () => {
      const [signer1] = await ethers.getSigners();
      const ERC20Factory = await ethers.getContractFactory("TestERC20");
      erc201 = await ERC20Factory.deploy(ethers.utils.parseEther("1000"));
      erc201 = await erc201.deployed();

      erc202 = await ERC20Factory.deploy(ethers.utils.parseEther("1000"));
      erc202 = await erc201.deployed();

      const StakingPoolFactory = await ethers.getContractFactory("StakingPool");
      stakingPool = await StakingPoolFactory.deploy(signer1.address, erc201.address, erc202.address, 5, 5);
      stakingPool = await stakingPool.deployed();

      await erc201.transfer(stakingPool.address, ethers.utils.parseEther("400"));
      await erc202.transfer(stakingPool.address, ethers.utils.parseEther("400"));
    });

    it("should allow to stake", async () => {
      await erc201.approve(stakingPool.address, ethers.utils.parseEther("200"));
      await expect(stakingPool.stakeAsset(erc201.address, ethers.utils.parseEther("200"))).to.emit(stakingPool, "Staked");
    });

    it("should allow withdrawals", async () => {
      await time.increase(time.duration.years(1));
      const [signer1] = await ethers.getSigners();
      const stakeId = await stakingPool.stakeIDs(0);
      await expect(() => stakingPool.withdrawRewards(stakeId)).to.changeTokenBalance(erc202, signer1, ethers.utils.parseUnits("210", 18));
    });
  });
});
