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

  bytes32 public securePauserRole = keccak256(abi.encodePacked("SECURE_PAUSER_ROLE"));
  bool isSecurePaused;
  address public rewardToken;
  address public immutable stakableToken;

  mapping(address => Stake) private stakes;

  constructor(
    address newOwner,
    address _rewardToken,
    address _stakableToken
  ) {
    require(_stakableToken == address(0) || _stakableToken.isContract(), "must_be_contract_or_zero_address");
    require(_rewardToken == address(0) || _rewardToken.isContract(), "must_be_contract_or_zero_address");
    rewardToken = _rewardToken;
    stakableToken = _stakableToken;
    _grantRole(securePauserRole, _msgSender());
    _transferOwnership(newOwner);
  }

  function stake(uint256 lockDays, uint256 amount) external payable whenNotPaused {
    Stake storage stakeS = stakes[_msgSender()];
    if (stakableToken == address(0)) {
      require(msg.value > 0, "must_stake_more_than_0_ether");
      stakeS.amountStaked = msg.value;
    } else {
      require(IERC20(stakableToken).allowance(_msgSender(), address(this)) >= amount, "not_enough_allowance");
      TransferHelpers._safeTransferFromERC20(stakableToken, _msgSender(), address(this), amount);
      stakeS.amountStaked = amount;
    }
    stakeS.lockIntervals = lockDays;
    stakeS.since = block.timestamp;
    stakeS.stakeLockedFor = block.timestamp.add(lockDays);
  }

  function unstakeAmount(uint256 amount) external nonReentrant {
    Stake storage stakeS = stakes[_msgSender()];
    require(stakeS.amountStaked > 0, "0");
    require(block.timestamp >= stakeS.stakeLockedFor, "cannot_unstake_now");
    if (stakableToken == address(0)) {
      TransferHelpers._safeTransferEther(_msgSender(), amount);
      stakeS.amountStaked = stakeS.amountStaked.sub(amount);
    } else {
      TransferHelpers._safeTransferERC20(stakableToken, _msgSender(), amount);
      stakeS.amountStaked = stakeS.amountStaked.sub(amount);
    }
  }

  function unstakeAll() external nonReentrant {
    Stake memory stakeS = stakes[_msgSender()];
    require(stakeS.amountStaked > 0, "0");
    require(block.timestamp >= stakeS.stakeLockedFor, "cannot_unstake_now");
    if (stakableToken == address(0)) {
      TransferHelpers._safeTransferEther(_msgSender(), stakeS.amountStaked);
    } else {
      TransferHelpers._safeTransferERC20(stakableToken, _msgSender(), stakeS.amountStaked);
    }
    delete stakes[_msgSender()];
  }

  function securePause() external {
    require(hasRole(securePauserRole, _msgSender()), "only_secure_pauser");
    require(!isSecurePaused, "already_secure_paused");

    if (!paused()) {
      _pause();
    }
    isSecurePaused = true;
  }

  function secureUnpause() external {
    require(hasRole(securePauserRole, _msgSender()), "only_secure_pauser");
    require(isSecurePaused, "not_secure_paused");
    isSecurePaused = false;
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    require(!isSecurePaused, "secure_paused");
    _unpause();
  }
}
