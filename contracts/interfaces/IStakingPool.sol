pragma solidity ^0.8.0;

interface IStakingPool {
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

  function stakes(bytes32)
    external
    view
    returns (
      uint256,
      address,
      uint256,
      address,
      bytes32
    );

  // function poolsByAddresses(address) external view returns (bytes32[] memory);

  function blockedAddresses(address) external view returns (bool);

  function stakeIDs(uint256) external view returns (bytes32);
}
