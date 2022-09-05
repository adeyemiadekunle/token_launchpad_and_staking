pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStakingPool.sol";
import "./helpers/TransferHelper.sol";

contract StakingPool is Ownable, AccessControl, Pausable, IStakingPool {
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
}
