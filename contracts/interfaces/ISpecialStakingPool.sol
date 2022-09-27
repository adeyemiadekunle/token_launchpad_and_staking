pragma solidity ^0.8.0;

interface ISpecialStakingPool {
  struct Stake {
    uint256 amountStaked;
    address tokenStaked;
    uint256 since;
    address staker;
    bytes32 stakeId;
  }

  event Staked(uint256 amount, address token, uint256 since, address staker, bytes32 stakeId);
  event Unstaked(uint256 amount, bytes32 stakeId);
  event Withdrawn(uint256 amount, bytes32 stakeId);
}
