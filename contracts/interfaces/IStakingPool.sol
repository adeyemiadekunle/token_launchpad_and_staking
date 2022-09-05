pragma solidity ^0.8.0;

interface IStakingPool {
  struct Stake {
    uint256 amountStaked;
    uint256 since;
    uint256 stakeLockedFor;
    uint256 lockIntervals;
  }
}
