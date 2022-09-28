pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStakingPool.sol";
import "./helpers/TransferHelper.sol";

contract StakingPool is Ownable, AccessControl, Pausable, ReentrancyGuard, IStakingPool {
  using SafeMath for uint256;
  using Address for address;

  bytes32 public pauserRole = keccak256(abi.encodePacked("PAUSER_ROLE"));
  address public immutable tokenA;
  address public immutable tokenB;
  uint256 public tokenAAPY;
  uint256 public tokenBAPY;

  mapping(bytes32 => Stake) public stakes;
  mapping(address => bytes32[]) public poolsByAddresses;
  mapping(address => bool) public blockedAddresses;

  constructor(
    address newOwner,
    address token0,
    address token1,
    uint256 apy1,
    uint256 apy2
  ) {
    require(token0.isContract(), "must_be_contract_or_zero_address");
    require(token1.isContract(), "must_be_contract_or_zero_address");
    tokenA = token0;
    tokenB = token1;
    tokenAAPY = apy1;
    tokenBAPY = apy2;
    _grantRole(pauserRole, _msgSender());
    _grantRole(pauserRole, newOwner);
    _transferOwnership(newOwner);
  }

  function calculateReward(bytes32 stakeId) public view returns (uint256 reward) {
    Stake memory stake = stakes[stakeId];
    uint256 percentage;
    if (stake.tokenStaked == tokenA) {
      // How much percentage reward does this staker yield?
      percentage = uint256(tokenBAPY).mul(block.timestamp.sub(stake.since) / (60 * 60 * 24 * 7 * 4)).div(12);
    } else {
      percentage = uint256(tokenAAPY).mul(block.timestamp.sub(stake.since) / (60 * 60 * 24 * 7 * 4)).div(12);
    }

    reward = stake.amountStaked.mul(percentage) / 100;
  }

  function stakeAsset(address token, uint256 amount) external whenNotPaused nonReentrant {
    require(token == tokenA || token == tokenB, "wrong_pool_to_stake_this_token");
    require(token.isContract(), "must_be_contract_address");
    require(!blockedAddresses[_msgSender()], "blocked");
    require(amount > 0, "must_stake_greater_than_0");
    require(IERC20(token).allowance(_msgSender(), address(this)) >= amount, "not_enough_allowance");
    TransferHelpers._safeTransferFromERC20(token, _msgSender(), address(this), amount);
    bytes32 stakeId = keccak256(abi.encodePacked(_msgSender(), address(this), token, block.timestamp));
    Stake memory stake = Stake({amountStaked: amount, tokenStaked: token, since: block.timestamp, staker: _msgSender(), stakeId: stakeId});
    stakes[stakeId] = stake;
    bytes32[] storage stakez = poolsByAddresses[_msgSender()];
    stakez.push(stakeId);
    emit Staked(amount, token, stake.since, _msgSender(), stakeId);
  }

  function unstakeAmount(bytes32 stakeId, uint256 amount) external whenNotPaused nonReentrant {
    Stake storage stake = stakes[stakeId];
    require(_msgSender() == stake.staker, "not_owner");
    TransferHelpers._safeTransferERC20(stake.tokenStaked, _msgSender(), amount);
    stake.amountStaked = stake.amountStaked.sub(amount);
    emit Unstaked(amount, stakeId);
  }

  function unstakeAll(bytes32 stakeId) external nonReentrant {
    Stake memory stake = stakes[stakeId];
    require(_msgSender() == stake.staker, "not_owner");
    TransferHelpers._safeTransferERC20(stake.tokenStaked, _msgSender(), stake.amountStaked);
    delete stakes[stakeId];

    bytes32[] storage stakez = poolsByAddresses[_msgSender()];

    for (uint256 i = 0; i < stakez.length; i++) {
      if (stakez[i] == stakeId) {
        stakez[i] = bytes32(0);
      }
    }
  }

  function pause() external {
    require(hasRole(pauserRole, _msgSender()), "only_pauser");
    _pause();
  }

  function unpause() external {
    require(hasRole(pauserRole, _msgSender()), "only_pauser");
    _unpause();
  }
}
